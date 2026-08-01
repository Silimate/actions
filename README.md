# Silimate Actions

Shared GitHub Actions building blocks for Silimate repositories: composite actions, reusable
workflows, and the shell scripts that run inside build containers.

This repository is **public** so that both public repos (`silisizer`, `liberty2json`, `prunefl`,
`vcd2fst`) and private ones can consume it. On the GitHub Free plan a *private* actions repository
is reachable only from other private repositories, which would exclude the public consumers.

## Layout

| Path | What it holds |
|------|---------------|
| `actions/` | Composite actions, run on the runner |
| `.github/workflows/` | `workflow_call` reusable workflows |
| `scripts/` | Plain shell, runs **inside** build containers (see below) |
| `selftest/` | Throwaway CMake project the self-test builds |

### Why `scripts/` exists separately

The CentOS 7 and Alpine builds use a hand-rolled `docker run` rather than `jobs.<id>.container`,
because the Actions runner needs Node 20/24 inside the container and CentOS 7's glibc 2.17 cannot
run it. Composite actions cannot reach inside a `docker run`, so container-side logic ships as
plain shell that is checked out into the bind-mounted workspace:

```yaml
- uses: actions/checkout@v7
  with:
    repository: Silimate/actions
    ref: v1
    path: .silimate-actions

- run: |
    docker run --rm -v "${{ github.workspace }}:/src" -w /src centos:7 bash -c '
      . /src/.silimate-actions/scripts/centos7-toolchain.sh
      cmake -S . -B build && cmake --build build -j$(nproc)
      /src/.silimate-actions/scripts/bundle-linux-libs.sh glibc /tmp/install/usr/local
    '
```

## Versioning

Consumers pin the moving major tag:

```yaml
uses: Silimate/actions/actions/build-metadata@v1
uses: Silimate/actions/.github/workflows/native-tarball-release.yml@v1
```

`v1` is force-moved to each release; immutable `v1.x.y` tags are also published for anyone who
wants to pin exactly. Breaking changes get a new major tag (`v2`) and `v1` keeps working.

## Reusable workflows

### `native-tarball-release.yml`

The full three-platform native build and release used by `liberty2json`, `prunefl`, `vcd2fst`, and
`flexnet`: an Alpine/musl "anylinux" tarball, a CentOS 7 "manylinux2014" tarball, a macOS arm64
tarball, then a permanent `build-<date>-<sha>` release plus a `latest` prerelease.

The caller supplies only the build script. `$STAGE`, `$PLATFORM`, `$NPROC` and
`$SILIMATE_ACTIONS_DIR` are set for it; the toolchain, dependency bundling, packaging
and release all come from here.

```yaml
jobs:
  release:
    uses: Silimate/actions/.github/workflows/native-tarball-release.yml@v1
    with:
      product: vcd2fst
      alpine-packages: libdwarf-dev elfutils-dev zlib-dev
      centos-packages: zlib-devel elfutils-devel elfutils-libelf-devel libdwarf-devel
      build-script: |
        cmake -DCMAKE_BUILD_TYPE=Release -S . -B build
        cmake --build build -j"$NPROC"
        cp build/vcd2fst "$STAGE/bin/"
```

Set `publish: false` for pull-request runs that should build and smoke-test but not
release, or `draft: true` for a dry run that publishes a draft and leaves the `latest`
tag alone.

### `cpp-cmake-ci.yml`

Matrix CMake build and `ctest` across Ubuntu and macOS, used by `silisizer`, `liberty2json`, and
`prunefl`.

### `self-hosted-python-checkin.yml`

The self-hosted Python check-in pipeline used by `preqorsor`, `smdb`, `silimem-mcp`,
`silimate-aon`, `opentitan-bugs`, and `opentitan-bugbench`: workspace wipe, checkout with
submodule SSH, Python setup, venv, lint, test, and the regression email report.

Every phase is optional, so a repo that only lints, or whose own `make test` builds the venv
(`create-venv: false`), still fits. The venv is put on `PATH`, so caller commands never need
`source .venv/bin/activate`.

## Source installers

`scripts/install-*.sh` build the dependencies no distro packages, or that CentOS 7 ships too old
a version of. They run in a container or on a runner, take an optional version argument, and
install into `/usr/local` by default:

| Script | Needed by |
|--------|-----------|
| `install-cudd.sh` | Every OpenSTA-derived tool; no distro packages CUDD |
| `install-tcl.sh` | CentOS 7, which only ships Tcl 8.5 |
| `install-tclreadline.sh` | Every platform; nothing packages it |
| `install-bison.sh` | CentOS 7, whose bison predates the grammars |
| `install-autotools.sh` | CentOS 7, for the autoconf 2.71 `autoreconf` needs |

`verify-relocatable.sh` asserts an extracted tarball resolves every shared library without help
from the build machine, and that macOS binaries carry a valid signature. Call it from a
`smoke-test:` block.

## Composite actions

| Action | Purpose |
|--------|---------|
| `clean-self-hosted-workspace` | Wipe a stale clone before checkout on a self-hosted runner |
| `checkout` | `actions/checkout` with the org's submodule and SSH conventions |
| `setup-python` | Python via `setup-python`, a `.python-version` file, or deadsnakes |
| `python-venv` | Create a venv and install the project into it |
| `build-metadata` | Emit `short_sha`, `full_sha`, `date`, and the canonical build tag |
| `bundle-linux-libs` | Bundle shared libraries and set RPATHs (runner-side wrapper) |
| `bundle-macos-dylibs` | Bundle dylibs, rewrite load paths, re-sign (runner-side wrapper) |
| `install-gh-cli` | Install the GitHub CLI on a runner that lacks it |
| `deploy-to-downloads` | rsync or scp to the Silimate downloads server over SSH |
| `send-regression-report` | Package test results and email them |

Each action's own `action.yml` documents its inputs.

## Conventions this repo standardizes

- `actions/checkout@v7`, `upload-artifact@v7`, `download-artifact@v8`, `setup-python@v7`,
  `setup-node@v7`, `cache@v6`, `github-script@v9`
- `alpine:3.21`, `centos:7`, `macos-15`, `ubuntu-latest`
- Artifacts named `<product>-<platform>-<arch>`, downloaded with `merge-multiple: true`
- Releases: permanent `build-YYYY-MM-DD-<short-sha>` plus a force-moved `latest` prerelease
- `secrets.GITHUB_TOKEN` for same-repo operations; a PAT only for genuinely cross-repo reads

## Development

`selftest.yml` builds a throwaway CMake project through every reusable workflow on all three
platforms. It runs on every push and pull request, and it is the gate for changes here.

```sh
shellcheck -x scripts/*.sh       # -x follows the source of _common.sh
actionlint                       # workflows are actionlint-clean
```
