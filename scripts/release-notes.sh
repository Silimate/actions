#!/bin/bash
# Build release_notes.md from the tarballs sitting in the working directory, and
# emit the asset list as the `assets` step output.
#
# Environment:
#   SHORT_SHA, FULL_SHA, DATE   From build-metadata.sh
#   REPO_URL                    e.g. https://github.com/Silimate/vcd2fst
#   INSTALL_PREFIX              Where the tarball extracts to, default /
#   EXTRA_NOTES                 Optional markdown appended at the end

set -euo pipefail

: "${GITHUB_OUTPUT:?release-notes.sh must run inside GitHub Actions}"
INSTALL_PREFIX="${INSTALL_PREFIX:-/}"

{
  echo "Automated build from \`${GITHUB_REF_NAME:-main}\` @ [\`${SHORT_SHA}\`](${REPO_URL}/commit/${FULL_SHA})"
  echo
  echo "| Platform | Archive | Install |"
  echo "|----------|---------|---------|"
} > release_notes.md

describe() {
  case "$1" in
    *-anylinux-amd64.tar.gz)      echo "Linux amd64 (musl, statically portable)" ;;
    *-manylinux2014-amd64.tar.gz) echo "Linux amd64 (manylinux2014, glibc 2.17+)" ;;
    *-linux-amd64.tar.gz)         echo "Linux amd64 (glibc 2.17+)" ;;
    *-macos-arm64.tar.gz)         echo "macOS arm64 (Apple Silicon)" ;;
    *)                            echo "$1" ;;
  esac
}

# One row per tarball that actually got built: platforms can be disabled per repo
ASSETS=""
for f in *.tar.gz; do
  [ -f "$f" ] || continue
  echo "| $(describe "$f") | \`$f\` | \`sudo tar xzf $f -C $INSTALL_PREFIX\` |" >> release_notes.md
  ASSETS="$ASSETS $f"
done

if [ -z "$ASSETS" ]; then
  echo "release-notes.sh: no *.tar.gz found to release" >&2
  exit 1
fi

{
  echo
  echo "**Built:** ${DATE}"
} >> release_notes.md

if [ -n "${EXTRA_NOTES:-}" ]; then
  {
    echo
    printf '%s\n' "$EXTRA_NOTES"
  } >> release_notes.md
fi

echo "assets=${ASSETS# }" >> "$GITHUB_OUTPUT"
cat release_notes.md
