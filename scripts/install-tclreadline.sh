#!/bin/sh
# Build and install tclreadline, which gives the interactive Tcl prompt GNU
# readline support. No platform we build on packages it.
#
#   install-tclreadline.sh [version]
#
# Environment (defaults suit a distro that packages Tcl and readline):
#   PREFIX                 Install prefix, default /usr/local
#   TCL_LIB_DIR            Directory holding libtcl, default /usr/lib
#   TCL_INCLUDE_DIR        Directory holding tcl.h, default /usr/include
#   READLINE_INCLUDE_DIR   Directory holding readline/readline.h, default /usr/include
#   READLINE_LIBRARY       Linker flags for readline, default -lreadline

set -eu

# shellcheck source=_common.sh source-path=SCRIPTDIR
. "$(dirname "$0")/_common.sh"

VERSION="${1:-2.4.1}"
PREFIX="${PREFIX:-/usr/local}"
TCL_LIB_DIR="${TCL_LIB_DIR:-/usr/lib}"
TCL_INCLUDE_DIR="${TCL_INCLUDE_DIR:-/usr/include}"
READLINE_INCLUDE_DIR="${READLINE_INCLUDE_DIR:-/usr/include}"
READLINE_LIBRARY="${READLINE_LIBRARY:--lreadline}"

SRC=$(mktemp -d)
git clone --depth 1 --branch "v${VERSION}" \
  https://github.com/flightaware/tclreadline "$SRC/tclreadline"

cd "$SRC/tclreadline"
# The committed configure is not standalone (LT_INIT is left unexpanded), so
# autoreconf has to run; on CentOS 7 that needs install-autotools.sh first
autoreconf -fi

# --with-tk=no: Tk is only needed for the optional wishrl target, which we do
# not build. Asking for it would require tkConfig.sh and drag in Tk and X11.
build_install "$SRC/tclreadline" \
  --prefix="$PREFIX" \
  --with-tcl="$TCL_LIB_DIR" \
  --with-tk=no \
  --with-tcl-includes="$TCL_INCLUDE_DIR" \
  --with-readline-includes="$READLINE_INCLUDE_DIR" \
  --with-readline-library="$READLINE_LIBRARY"

cd /
rm -rf "$SRC"
echo "install-tclreadline.sh: installed tclreadline ${VERSION} into ${PREFIX}"
