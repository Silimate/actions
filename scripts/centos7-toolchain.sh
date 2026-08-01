#!/bin/sh
# Bring a centos:7 container up to a usable C++17 toolchain.
#
# MUST BE SOURCED, not executed: it exports PATH and sources the devtoolset
# enable script, both of which have to survive into the caller's shell.
#
#   . /src/.silimate-actions/scripts/centos7-toolchain.sh
#
# Optional environment:
#   SILIMATE_ACTIONS_DIR  Where this repo is checked out (default /src/.silimate-actions)
#   CMAKE_VERSION         CMake to fetch (default 3.31.4); CentOS 7 ships 2.8
#   EXTRA_PACKAGES        Additional yum packages, space separated
#   WITH_NINJA            Non-empty to also install ninja-build

set -e

SILIMATE_ACTIONS_DIR="${SILIMATE_ACTIONS_DIR:-/src/.silimate-actions}"
CMAKE_VERSION="${CMAKE_VERSION:-3.31.4}"

# shellcheck disable=SC1091
. "$SILIMATE_ACTIONS_DIR/scripts/centos7-vault-repos.sh"

# Deliberately unquoted: these expand to zero or more separate package names
# shellcheck disable=SC2086
yum install -y devtoolset-11-gcc-c++ make git curl patchelf \
  ${WITH_NINJA:+ninja-build} ${EXTRA_PACKAGES:-}

# CentOS 7's cmake is far too old for any modern CMakeLists, so drop a
# current one into /opt and put it first on PATH.
curl -fL --retry 5 --retry-delay 3 \
  "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" \
  | tar -xzC /opt
PATH="/opt/cmake-${CMAKE_VERSION}-linux-x86_64/bin:$PATH"
export PATH

# devtoolset-11 is the gcc 11 SCL; without this the default gcc 4.8 is used
# shellcheck disable=SC1091
. /opt/rh/devtoolset-11/enable
