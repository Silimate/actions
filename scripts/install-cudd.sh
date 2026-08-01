#!/bin/sh
# Build and install CUDD, the BDD library the OpenSTA-derived tools link against.
# No distro packages it, so every repo that needs it builds it from source.
#
#   install-cudd.sh [version]
#
# POSIX sh, because this also runs inside Alpine containers, which have no bash.

set -eu

VERSION="${1:-3.0.0}"

# Containers run as root and have no sudo; runners are non-root and do
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

NPROC=$(nproc 2>/dev/null || echo 4)
WORKDIR=$(mktemp -d)

curl -fL --retry 5 --retry-delay 3 \
  "https://raw.githubusercontent.com/davidkebo/cudd/main/cudd_versions/cudd-${VERSION}.tar.gz" \
  | tar -xzC "$WORKDIR"

cd "$WORKDIR/cudd-${VERSION}"
./configure
make -j"$NPROC"
$SUDO make install

cd /
rm -rf "$WORKDIR"
echo "install-cudd.sh: installed CUDD ${VERSION}"
