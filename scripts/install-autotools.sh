#!/bin/sh
# Build and install a modern autoconf, automake and libtool from source.
#
# CentOS 7 ships autoconf 2.69 at best, but tclreadline's configure.ac needs
# 2.71 or newer, so autoreconf has to be run with these instead.

set -eu

# shellcheck source=_common.sh source-path=SCRIPTDIR
. "$(dirname "$0")/_common.sh"

AUTOCONF_VERSION="${AUTOCONF_VERSION:-2.71}"
AUTOMAKE_VERSION="${AUTOMAKE_VERSION:-1.16.5}"
LIBTOOL_VERSION="${LIBTOOL_VERSION:-2.4.7}"
PREFIX="${PREFIX:-/usr/local}"

# Order matters: automake's configure looks for the autoconf we just installed
for pkg in "autoconf/autoconf-${AUTOCONF_VERSION}" \
           "automake/automake-${AUTOMAKE_VERSION}" \
           "libtool/libtool-${LIBTOOL_VERSION}"; do
  name=${pkg#*/}
  SRC=$(fetch_source "https://ftp.gnu.org/gnu/${pkg}.tar.gz")
  build_install "$SRC/$name" --prefix="$PREFIX"
  cd /
  rm -rf "$SRC"
done

# The shell has the old autoconf's path cached from the yum-installed version
hash -r 2>/dev/null || true

echo "install-autotools.sh: installed autoconf ${AUTOCONF_VERSION}, automake ${AUTOMAKE_VERSION}, libtool ${LIBTOOL_VERSION}"
