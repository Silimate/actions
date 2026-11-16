#!/bin/sh
# Build and install CUDD, the BDD library the OpenSTA-derived tools link against.
# No distro packages it, so every repo that needs it builds it from source.
#
#   install-cudd.sh [version]
#
# POSIX sh, because this also runs inside Alpine containers, which have no bash.

set -eu

VERSION="${1:-3.0.0}"

# A release asset can be replaced upstream, so each version's hash is pinned here
case "$VERSION" in
  3.0.0) SHA256=b8e966b4562c96a03e7fbea239729587d7b395d53cadcc39a7203b49cf7eeb69 ;;
  *) echo "install-cudd.sh: no sha256 pinned for CUDD ${VERSION}" >&2; exit 1 ;;
esac

# Containers run as root and have no sudo; runners are non-root and do
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

NPROC=$(nproc 2>/dev/null || echo 4)
WORKDIR=$(mktemp -d)

TARBALL="$WORKDIR/cudd-${VERSION}.tar.gz"
curl -fL --retry 5 --retry-delay 3 -o "$TARBALL" \
  "https://github.com/davidkebo/cudd/releases/download/v${VERSION}/cudd-${VERSION}.tar.gz"
# Alpine has no shasum and older macOS no sha256sum
SUM=$(sha256sum "$TARBALL" 2>/dev/null || shasum -a 256 "$TARBALL")
if [ "${SUM%% *}" != "$SHA256" ]; then
  echo "install-cudd.sh: sha256 mismatch for cudd-${VERSION}.tar.gz" >&2
  exit 1
fi
tar -xzC "$WORKDIR" -f "$TARBALL"

cd "$WORKDIR/cudd-${VERSION}"
./configure
make -j"$NPROC"
$SUDO make install

cd /
rm -rf "$WORKDIR"
echo "install-cudd.sh: installed CUDD ${VERSION}"
