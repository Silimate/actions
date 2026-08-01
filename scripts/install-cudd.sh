#!/bin/bash
# Build and install CUDD, the BDD library OpenSTA-derived tools link against.
# No distro packages it, so every repo that needs it builds it from source.
#
#   install-cudd.sh [version]

set -euo pipefail

VERSION="${1:-3.0.0}"
WORKDIR=$(mktemp -d)

curl -fL --retry 5 --retry-delay 3 \
  "https://raw.githubusercontent.com/davidkebo/cudd/main/cudd_versions/cudd-${VERSION}.tar.gz" \
  | tar -xzC "$WORKDIR"

cd "$WORKDIR/cudd-${VERSION}"
./configure
make -j"$(getconf _NPROCESSORS_ONLN)"
sudo make install

cd /
rm -rf "$WORKDIR"
echo "install-cudd.sh: installed CUDD ${VERSION}"
