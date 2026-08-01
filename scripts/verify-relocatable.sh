#!/bin/sh
# Assert that an extracted tarball is self-contained: every executable resolves
# all of its shared libraries without help from the build machine.
#
#   verify-relocatable.sh <extracted-root>
#
# Set BIN_DIRS for products that ship executables outside bin/, and PREFIX when
# the tarball extracts under a prefix, e.g. PREFIX=usr/local.
#
# POSIX sh: this runs inside Alpine smoke-test containers, which have no bash.

set -eu

ROOT="${1:?usage: verify-relocatable.sh <extracted-root>}"
BIN_DIRS="${BIN_DIRS:-bin}"
PREFIX="${PREFIX:-}"

BASE="$ROOT"
if [ -n "$PREFIX" ]; then
  BASE="$ROOT/$PREFIX"
fi

FAILED=0
CHECKED=0

check_linux() {
  # An unresolvable dependency is "not found" under glibc and "Error loading
  # shared library" under musl; either one means the bundle is incomplete
  if ldd "$1" 2>&1 | grep -qE "not found|Error loading shared library"; then
    echo "::error::$1 has unresolved libraries:"
    ldd "$1" 2>&1 | grep -E "not found|Error loading shared library"
    FAILED=1
  fi
}

check_macos() {
  # Anything still pointing at an absolute path outside the OS directories came
  # from the build machine and will not exist on a user's Mac
  # Dependency lines are tab-indented; unindented ones are headers, and a
  # universal binary prints one header per architecture, not just the first
  otool -L "$1" | awk '/^[[:space:]]/ {print $1}' | while read -r lib; do
    case "$lib" in
      /usr/lib/*|/System/*|@rpath/*|@loader_path/*|@executable_path/*) ;;
      *) echo "::error::$1 still references $lib"; exit 1 ;;
    esac
  done || FAILED=1

  # install_name_tool invalidates signatures, and arm64 macOS will not run a
  # binary whose signature is stale
  if ! codesign -v "$1" 2>/dev/null; then
    echo "::error::$1 has an invalid code signature"
    FAILED=1
  fi
}

for d in $BIN_DIRS; do
  for f in "$BASE/$d"/*; do
    [ -f "$f" ] || continue
    CHECKED=$((CHECKED + 1))
    if command -v otool >/dev/null 2>&1; then
      check_macos "$f"
    else
      check_linux "$f"
    fi
  done
done

if [ "$CHECKED" -eq 0 ]; then
  echo "::error::verify-relocatable.sh found no executables under $BASE" >&2
  exit 1
fi

if [ "$FAILED" -ne 0 ]; then
  exit 1
fi

echo "verify-relocatable.sh: $CHECKED executables are self-contained"
