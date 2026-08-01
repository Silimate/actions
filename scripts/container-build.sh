#!/bin/sh
# Drive a native build inside an Alpine or CentOS 7 container: install packages,
# run the caller's build script, bundle shared libraries, and produce a tarball.
#
#   container-build.sh <musl|glibc>
#
# Environment (all set by native-tarball-release.yml):
#   PRODUCT               Product name, used for the tarball filename
#   PLATFORM              Platform label, e.g. anylinux-amd64
#   PACKAGES              Packages to install before building
#   STAGE                 Prefix the build script installs into
#   BUILD_SCRIPT          Path to the caller's build script
#   SILIMATE_ACTIONS_DIR  Where this repo is checked out inside the container
#   SRC_DIR               Source checkout, and where the tarball is written

set -eu

LIBC="${1:?usage: container-build.sh <musl|glibc>}"

PRODUCT="${PRODUCT:?}"
PLATFORM="${PLATFORM:?}"
STAGE="${STAGE:-/tmp/install/usr/local}"
BUILD_SCRIPT="${BUILD_SCRIPT:?}"
SILIMATE_ACTIONS_DIR="${SILIMATE_ACTIONS_DIR:-/src/.silimate-actions}"
SRC_DIR="${SRC_DIR:-/src}"
export STAGE PLATFORM SILIMATE_ACTIONS_DIR

# Install the toolchain and the caller's build dependencies
case "$LIBC" in
  musl)
    # shellcheck disable=SC2086
    apk add --no-cache build-base cmake git patchelf \
      ${WITH_NINJA:+ninja} ${PACKAGES:-}
    ;;
  glibc)
    EXTRA_PACKAGES="${PACKAGES:-}"
    export EXTRA_PACKAGES
    # WITH_NINJA is forwarded from the workflow's with-ninja input
    # shellcheck disable=SC1091
    . "$SILIMATE_ACTIONS_DIR/scripts/centos7-toolchain.sh"
    ;;
  *)
    echo "container-build.sh: libc must be musl or glibc, got '$LIBC'" >&2
    exit 2
    ;;
esac

cd "$SRC_DIR"

# The checkout is owned by the runner user, not root, so git refuses to touch it
git config --global --add safe.directory "$SRC_DIR"
# $toplevel and $sm_path are expanded by git submodule foreach, not by the shell
# shellcheck disable=SC2016
git submodule foreach --recursive \
  'git config --global --add safe.directory $toplevel/$sm_path' 2>/dev/null || true

# NPROC is a convenience for build scripts that parallelize
NPROC=$(nproc 2>/dev/null || echo 4)
export NPROC

mkdir -p "$STAGE/bin" "$STAGE/lib"

echo "=== build ($PRODUCT $PLATFORM) ==="
sh -e "$BUILD_SCRIPT"

echo "=== bundle ($LIBC) ==="
"$SILIMATE_ACTIONS_DIR/scripts/bundle-linux-libs.sh" "$LIBC" "$STAGE"

echo "=== package ==="
# Tar from the install root so the archive extracts with `tar xzf ... -C /`
INSTALL_ROOT="${STAGE%/usr/local}"
cd "$INSTALL_ROOT"
tar czf "$SRC_DIR/${PRODUCT}-${PLATFORM}.tar.gz" .
ls -la "$SRC_DIR/${PRODUCT}-${PLATFORM}.tar.gz"
