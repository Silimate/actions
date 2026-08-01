#!/bin/bash
# Bundle non-system dylibs next to the binaries, rewrite their load paths to be
# relocatable, and re-sign, so the staged tree runs on a Mac without Homebrew.
#
#   bundle-macos-dylibs.sh <stage-dir>
#
# <stage-dir> is the prefix holding bin/ and lib/, e.g. /tmp/install/usr/local.
#
# Set BIN_DIRS to override which subdirectories hold executables when the
# product ships more than bin/, e.g. BIN_DIRS="bin license".

set -euo pipefail

STAGE="${1:?usage: bundle-macos-dylibs.sh <stage-dir>}"
BIN_DIRS="${BIN_DIRS:-bin}"

mkdir -p "$STAGE/lib"

# Expand BIN_DIRS into the list of executables to walk
executables() {
  # shellcheck disable=SC2086
  for d in $BIN_DIRS; do
    for f in "$STAGE/$d"/*; do
      if [ -f "$f" ]; then
        echo "$f"
      fi
    done
  done
}

bundle_dylibs() {
  for f in "$@"; do
    [ -f "$f" ] || continue
    # Dependency lines are tab-indented; unindented ones name the file itself,
    # once per architecture in a universal binary
    otool -L "$f" 2>/dev/null | awk '/^[[:space:]]/ {print $1}' | while read -r lib; do
      # Skip OS-supplied dylibs and paths we have already rewritten
      # (@rpath/... is not a real file, so the -f test catches those too)
      [ -f "$lib" ] || continue
      case "$lib" in /usr/lib/*|/System/*) continue ;; esac

      base=$(basename "$lib")
      if [ ! -f "$STAGE/lib/$base" ]; then
        cp "$lib" "$STAGE/lib/$base"
        # Homebrew ships dylibs mode 0444; install_name_tool needs them writable
        chmod u+w "$STAGE/lib/$base"
        install_name_tool -id "@rpath/$base" "$STAGE/lib/$base" 2>/dev/null || true
      fi
      install_name_tool -change "$lib" "@rpath/$base" "$f" 2>/dev/null || true
    done
  done
}

# Iterate to a fixed point: a bundled dylib can itself pull in dylibs that were
# not visible from the binaries alone (libtclreadline -> libreadline).
while :; do
  before=$(find "$STAGE/lib" -maxdepth 1 | wc -l)
  # shellcheck disable=SC2046
  bundle_dylibs $(executables) "$STAGE"/lib/*.dylib
  after=$(find "$STAGE/lib" -maxdepth 1 | wc -l)
  if [ "$before" = "$after" ]; then
    break
  fi
done

# Give @rpath somewhere to resolve to
executables | while read -r f; do
  install_name_tool -add_rpath "@executable_path/../lib" "$f" 2>/dev/null || true
done
for f in "$STAGE"/lib/*.dylib; do
  if [ -f "$f" ]; then
    install_name_tool -add_rpath "@loader_path" "$f" 2>/dev/null || true
  fi
done

# install_name_tool invalidates the code signature, and arm64 macOS refuses to
# load a binary whose signature is stale. Re-sign everything ad-hoc.
executables | while read -r f; do
  codesign --force --sign - "$f" 2>/dev/null || true
done
for f in "$STAGE"/lib/*.dylib; do
  if [ -f "$f" ]; then
    codesign --force --sign - "$f" 2>/dev/null || true
  fi
done

echo "bundle-macos-dylibs.sh: bundled $(find "$STAGE/lib" -maxdepth 1 -name '*.dylib' | wc -l) dylibs into $STAGE/lib"
