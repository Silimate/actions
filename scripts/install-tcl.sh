#!/bin/sh
# Build and install Tcl from source and make `tclsh` resolve to it.
#
#   install-tcl.sh [version]
#
# Needed on CentOS 7, which only ships Tcl 8.5.

set -eu

# shellcheck source=_common.sh source-path=SCRIPTDIR
. "$(dirname "$0")/_common.sh"

VERSION="${1:-8.6.16}"
PREFIX="${PREFIX:-/usr/local}"
MAJOR_MINOR=$(echo "$VERSION" | cut -d. -f1,2)

SRC=$(fetch_source "https://prdownloads.sourceforge.net/tcl/tcl${VERSION}-src.tar.gz")
build_install "$SRC/tcl${VERSION}/unix" --prefix="$PREFIX" --enable-shared

# The build only installs tclsh<major.minor>; CMake's FindTCL looks for tclsh
$SUDO ln -sf "$PREFIX/bin/tclsh${MAJOR_MINOR}" "$PREFIX/bin/tclsh"

rm -rf "$SRC"
echo "install-tcl.sh: installed Tcl ${VERSION} into ${PREFIX}"
