# Sourced by the install-* scripts; not runnable on its own.
#
# POSIX sh, because these run inside Alpine containers, which have no bash.
# shellcheck shell=sh

# Containers run as root and have no sudo; runners are non-root and do
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  SUDO="sudo"
fi

NPROC=$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)

# Download a source tarball into a fresh temp directory and echo that directory.
# Uses canonical hosts rather than redirectors like ftpmirror.gnu.org, which
# intermittently hand back an HTML error page instead of the tarball; -f turns
# that into a failure and --retry rides out transient hiccups.
fetch_source() {
  _dir=$(mktemp -d)
  curl -fL --retry 5 --retry-delay 3 "$1" | tar -xzC "$_dir"
  echo "$_dir"
}

# configure, make, make install in the given directory; extra args go to configure
build_install() {
  _src="$1"
  shift
  cd "$_src" || return 1
  ./configure "$@"
  make -j"$NPROC"
  $SUDO make install
}
