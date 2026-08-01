#!/bin/sh
# Bundle non-system shared libraries next to the binaries and set RPATHs so the
# staged tree runs on a machine that has none of the build dependencies.
#
#   bundle-linux-libs.sh <musl|glibc> <stage-dir>
#
# <stage-dir> is the prefix holding bin/ and lib/, e.g. /tmp/install/usr/local.
#
# Runs under Alpine's busybox ash and CentOS 7's bash, so POSIX sh only.

set -eu

LIBC="${1:?usage: bundle-linux-libs.sh <musl|glibc> <stage-dir>}"
STAGE="${2:?usage: bundle-linux-libs.sh <musl|glibc> <stage-dir>}"

case "$LIBC" in
  musl|glibc) ;;
  *) echo "bundle-linux-libs.sh: libc must be musl or glibc, got '$LIBC'" >&2; exit 2 ;;
esac

mkdir -p "$STAGE/lib"

# Libraries supplied by the target system; copying them breaks more than it fixes
is_system_lib() {
  case "$LIBC" in
    musl)
      case "$1" in ld-musl-*|libc.musl-*) return 0 ;; esac
      ;;
    glibc)
      case "$1" in ld-linux*|libc.so*|libdl*|libpthread*|librt*|libm.so*) return 0 ;; esac
      ;;
  esac
  return 1
}

copy_deps() {
  for f in "$@"; do
    [ -f "$f" ] || continue
    ldd "$f" 2>/dev/null | awk '/=>/ {print $3}' | while read -r lib; do
      [ -f "$lib" ] || continue
      base=$(basename "$lib")
      if ! is_system_lib "$base" && [ ! -f "$STAGE/lib/$base" ]; then
        cp "$lib" "$STAGE/lib/$base"
        chmod u+w "$STAGE/lib/$base"
      fi
    done
  done
}

# Iterate to a fixed point: a bundled library can itself pull in libraries that
# were not visible from the binaries alone (libtclreadline -> libreadline ->
# libncurses). A single pass silently ships a tree that fails to load.
while :; do
  before=$(find "$STAGE/lib" -maxdepth 1 | wc -l)
  copy_deps "$STAGE"/bin/* "$STAGE"/lib/*.so*
  after=$(find "$STAGE/lib" -maxdepth 1 | wc -l)
  if [ "$before" = "$after" ]; then
    break
  fi
done

# Executables look one level up into lib/, libraries look beside themselves.
# $ORIGIN is an ELF dynamic-string token resolved by the loader, so it has to
# reach patchelf literally: single quotes are required here.
for f in "$STAGE"/bin/*; do
  if [ -f "$f" ]; then
    # shellcheck disable=SC2016
    patchelf --set-rpath '$ORIGIN/../lib' "$f" 2>/dev/null || true
  fi
done
for f in "$STAGE"/lib/*.so*; do
  if [ -f "$f" ]; then
    # shellcheck disable=SC2016
    patchelf --set-rpath '$ORIGIN' "$f" 2>/dev/null || true
  fi
done

echo "bundle-linux-libs.sh: bundled $(find "$STAGE/lib" -maxdepth 1 -name '*.so*' | wc -l) libraries into $STAGE/lib"
