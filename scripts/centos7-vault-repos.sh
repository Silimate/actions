#!/bin/sh
# Repoint CentOS 7 yum repos at vault.centos.org.
#
# CentOS 7 is EOL and mirror.centos.org no longer serves it, so every yum
# operation in a centos:7 container fails until the repo files are rewritten.
# The rewrite has to happen twice: installing centos-release-scl/epel-release
# drops in fresh .repo files that point at the dead mirror again.
#
# Safe to source or execute.

set -e

# Swap the dead mirror for the vault and force baseurl over mirrorlist
vault_repos() {
  sed -i 's/mirror.centos.org/vault.centos.org/g' /etc/yum.repos.d/*.repo
  sed -i 's/^#.*baseurl=http/baseurl=http/g' /etc/yum.repos.d/*.repo
  sed -i 's/^mirrorlist=http/#mirrorlist=http/g' /etc/yum.repos.d/*.repo
}

vault_repos
yum install -y centos-release-scl epel-release
vault_repos
