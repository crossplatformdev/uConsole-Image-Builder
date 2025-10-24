#!/bin/bash
set -euo pipefail

OUTDIR="${1:-output}"
TIMESTAMP="${2:-$(date +%Y%m%d)}"
ASSETDIR="$OUTDIR/release-assets/$TIMESTAMP"
mkdir -p "$ASSETDIR"

# Copy image(s)
find "$OUTDIR" -maxdepth 1 -type f -name "uconsole-cm4-*.img.xz" -exec cp {} "$ASSETDIR/" \; || true

# Copy kernel .debs
find "$OUTDIR" -type f -name "*.deb" -exec cp {} "$ASSETDIR/" \; || true

# Copy kernel build artifacts
cp -r "$OUTDIR/kernel-build" "$ASSETDIR/" 2>/dev/null || true

# Create source tarball of current commit
git archive --format=tar.gz -o "$ASSETDIR/uConsole-Image-Builder-src-${TIMESTAMP}.tar.gz" HEAD || true

echo "Release assets prepared in $ASSETDIR"
echo "Upload all files in $ASSETDIR as tag assets for your release."
