#!/usr/bin/env bash
# download-debs.sh — Download all RustDesk .deb packages for a given version.
# Skips files that already exist in the pool (idempotent).
set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
POOL_DIR="docs/pool/main/r/rustdesk"

echo "==> Downloading RustDesk $VERSION .deb packages..."
mkdir -p "$POOL_DIR"

BASE_URL="https://github.com/rustdesk/rustdesk/releases/download/${VERSION}"

# Package filename suffix → APT architecture label
declare -A PACKAGES=(
  ["x86_64.deb"]="amd64"
  ["aarch64.deb"]="arm64"
  ["armv7-sciter.deb"]="armhf"
)

ANY_DOWNLOADED=0

for SUFFIX in "${!PACKAGES[@]}"; do
  PKG="rustdesk-${VERSION}-${SUFFIX}"
  DEST="$POOL_DIR/$PKG"
  URL="$BASE_URL/$PKG"

  if [ -f "$DEST" ]; then
    echo "  [skip] $PKG already in pool"
    continue
  fi

  echo "  [fetch] $URL"
  HTTP_STATUS=$(curl -sSL -w "%{http_code}" -o "$DEST.tmp" "$URL")

  if [ "$HTTP_STATUS" -eq 200 ]; then
    mv "$DEST.tmp" "$DEST"
    SIZE=$(du -sh "$DEST" | cut -f1)
    echo "  [ok]   $PKG  ($SIZE)"
    ANY_DOWNLOADED=1
  else
    rm -f "$DEST.tmp"
    echo "  [warn] $PKG not available upstream (HTTP $HTTP_STATUS) — skipping"
  fi
done

echo "==> Done for $VERSION."
if [ "$ANY_DOWNLOADED" -eq 0 ]; then
  echo "  (all files were already present or unavailable upstream)"
fi