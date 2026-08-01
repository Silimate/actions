#!/bin/sh
# Build and install GNU bison from source.
#
#   install-bison.sh [version]
#
# Needed on CentOS 7, which ships bison 3.0.4; the OpenSTA-derived grammars
# need 3.x features that only landed later.

set -eu

# shellcheck source=_common.sh source-path=SCRIPTDIR
. "$(dirname "$0")/_common.sh"

VERSION="${1:-3.8.2}"
SRC=$(fetch_source "https://ftp.gnu.org/gnu/bison/bison-${VERSION}.tar.gz")
build_install "$SRC/bison-${VERSION}"
rm -rf "$SRC"
echo "install-bison.sh: installed bison ${VERSION}"
