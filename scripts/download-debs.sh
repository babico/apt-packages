#!/usr/bin/env bash
# download-debs.sh — Download all .deb files for a single RustDesk version.
# Idempotent: skips files already present in the pool.
set -euo pipefail

VERSION="${1:?Usage: $0 <version>}"
POOL_DIR="docs/pool/main/r/rustdesk"

echo "==> RustDesk $VERSION"
mkdir -p "$POOL_DIR"

BASE="https://github.com/rustdesk/rustdesk/releases/download/${VERSION}"

declare -A PKGS=(
  ["rustdesk-${VERSION}-x86_64.deb"]="amd64"
  ["rustdesk-${VERSION}-aarch64.deb"]="arm64"
  ["rustdesk-${VERSION}-armv7-sciter.deb"]="armhf"
)

ANY_NEW=0
for PKG in "${!PKGS[@]}"; do
  DEST="$POOL_DIR/$PKG"
  if [ -f "$DEST" ]; then
    echo "  [skip]  $PKG"
    continue
  fi
  echo "  [fetch] $PKG"
  HTTP=$(curl -sSL -w "%{http_code}" -o "${DEST}.tmp" "$BASE/$PKG")
  if [ "$HTTP" = "200" ]; then
    mv "${DEST}.tmp" "$DEST"
    echo "  [ok]    $PKG ($(du -sh "$DEST" | cut -f1))"
    ANY_NEW=1
  else
    rm -f "${DEST}.tmp"
    echo "  [miss]  $PKG — HTTP $HTTP (not available upstream)"
  fi
done

[ "$ANY_NEW" -eq 0 ] && echo "  (all files already present)"
echo ""