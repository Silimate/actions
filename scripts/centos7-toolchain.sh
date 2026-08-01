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
#   NINJA_VERSION         Ninja to fetch (default 1.11.1)
#   EXTRA_PACKAGES        Additional yum packages, space separated
#   WITH_NINJA            Non-empty to also install Ninja

set -e

SILIMATE_ACTIONS_DIR="${SILIMATE_ACTIONS_DIR:-/src/.silimate-actions}"
CMAKE_VERSION="${CMAKE_VERSION:-3.31.4}"
NINJA_VERSION="${NINJA_VERSION:-1.11.1}"

# shellcheck disable=SC1091
. "$SILIMATE_ACTIONS_DIR/scripts/centos7-vault-repos.sh"

# Deliberately unquoted: this expands to zero or more separate package names
# shellcheck disable=SC2086
yum install -y devtoolset-11-gcc-c++ make git curl unzip patchelf ${EXTRA_PACKAGES:-}

# CentOS 7's cmake is far too old for any modern CMakeLists, so drop a
# current one into /opt and put it first on PATH.
curl -fL --retry 5 --retry-delay 3 \
  "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz" \
  | tar -xzC /opt
PATH="/opt/cmake-${CMAKE_VERSION}-linux-x86_64/bin:$PATH"
export PATH

# Ninja comes from the upstream release rather than EPEL, which is archived
# alongside CentOS 7 and cannot be relied on
if [ -n "${WITH_NINJA:-}" ]; then
  curl -fL --retry 5 --retry-delay 3 -o /tmp/ninja.zip \
    "https://github.com/ninja-build/ninja/releases/download/v${NINJA_VERSION}/ninja-linux.zip"
  unzip -o -d /usr/local/bin /tmp/ninja.zip
  chmod +x /usr/local/bin/ninja
  rm -f /tmp/ninja.zip
fi

# devtoolset-11 is the gcc 11 SCL; without this the default gcc 4.8 is used
# shellcheck disable=SC1091
. /opt/rh/devtoolset-11/enable
