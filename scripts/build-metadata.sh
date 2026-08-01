#!/bin/bash
# Emit the commit and date facts that Silimate release workflows build their tag
# and release notes from. Appends to $GITHUB_OUTPUT. Requires a full-history checkout.

set -euo pipefail

SHORT_SHA=$(git rev-parse --short HEAD)
FULL_SHA=$(git rev-parse HEAD)
DATE=$(date -u +%Y-%m-%d)

{
  echo "short_sha=$SHORT_SHA"
  echo "full_sha=$FULL_SHA"
  echo "date=$DATE"
  echo "tag=build-$DATE-$SHORT_SHA"
  echo "title=Build $DATE ($SHORT_SHA)"
} >> "${GITHUB_OUTPUT:?build-metadata.sh must run inside GitHub Actions}"

echo "build-metadata.sh: tag=build-$DATE-$SHORT_SHA"
