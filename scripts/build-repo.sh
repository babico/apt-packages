#!/usr/bin/env bash
# build-repo.sh — (Re)build the full APT repository index from all .deb files in the pool.
# Handles multiple versions for every architecture simultaneously.
set -euo pipefail

LATEST_VERSION="${1:?Usage: $0 <latest_version> [gpg_key_id] [gpg_passphrase]}"
GPG_KEY_ID="${2:-}"
GPG_PASSPHRASE="${3:-}"

REPO_ROOT="docs"
DIST="stable"
COMPONENT="main"
POOL_DIR="$REPO_ROOT/pool/$COMPONENT/r/rustdesk"
DISTS_DIR="$REPO_ROOT/dists/$DIST"

echo "==> Building APT repository index (all versions in pool)..."

# Clean old index files so stale entries don't linger
rm -rf "$DISTS_DIR"
mkdir -p "$DISTS_DIR/$COMPONENT"

# ── Per-architecture Packages files ──────────────────────────────────────────
# dpkg-scanpackages cannot filter by arch on its own for mixed pools, so we
# separate .deb files into per-arch staging dirs, scan, then discard staging.

declare -A ARCH_SUFFIX_MAP=(
  ["amd64"]="x86_64.deb"
  ["arm64"]="aarch64.deb"
  ["armhf"]="armv7-sciter.deb"
)

STAGING_ROOT="$(mktemp -d)"
trap 'rm -rf "$STAGING_ROOT"' EXIT

for APT_ARCH in "${!ARCH_SUFFIX_MAP[@]}"; do
  SUFFIX="${ARCH_SUFFIX_MAP[$APT_ARCH]}"
  STAGE_POOL="$STAGING_ROOT/$APT_ARCH/pool/$COMPONENT/r/rustdesk"
  mkdir -p "$STAGE_POOL"

  # Hard-link matching .deb files into the staging pool (no disk copy)
  find "$POOL_DIR" -name "*-${SUFFIX}" 2>/dev/null | while read -r DEB; do
    ln "$DEB" "$STAGE_POOL/$(basename "$DEB")" 2>/dev/null \
      || cp "$DEB" "$STAGE_POOL/$(basename "$DEB")"
  done

  DEB_COUNT=$(find "$STAGE_POOL" -name '*.deb' | wc -l)

  if [ "$DEB_COUNT" -eq 0 ]; then
    echo "  [skip] No .deb files for $APT_ARCH"
    continue
  fi

  PKG_DIR="$DISTS_DIR/$COMPONENT/binary-$APT_ARCH"
  mkdir -p "$PKG_DIR"

  echo "  [index] $APT_ARCH — $DEB_COUNT package(s)"

  # Scan from the staging root so pool paths in Packages are relative to repo root
  (cd "$STAGING_ROOT/$APT_ARCH" && \
    dpkg-scanpackages "pool/$COMPONENT/r/rustdesk" /dev/null 2>/dev/null) \
    > "$PKG_DIR/Packages"

  # Rewrite pool paths to point at the real (non-staging) pool inside docs/
  # dpkg-scanpackages emits "Filename: pool/..." relative to its CWD;
  # we need it relative to the GitHub Pages root (docs/).
  sed -i "s|^Filename: pool/|Filename: pool/|" "$PKG_DIR/Packages"

  gzip -9 -k -f "$PKG_DIR/Packages"

  PKG_COUNT=$(grep -c '^Package:' "$PKG_DIR/Packages" || true)
  echo "  [ok]   $APT_ARCH — $PKG_COUNT entries written"
done

# ── Release file ──────────────────────────────────────────────────────────────
echo "==> Generating Release file..."

REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-your-github-username}"
REPO_SLUG="${GITHUB_REPOSITORY:-your-github-username/rustdesk-apt}"

# Count distinct versions in pool
TOTAL_VERSIONS=$(find "$POOL_DIR" -name '*.deb' 2>/dev/null \
  | grep -oP 'rustdesk-\K[^-]+(?=-)' | sort -uV | wc -l || echo "?")

cat > "$DISTS_DIR/Release" <<EOF
Origin: RustDesk APT Mirror
Label: RustDesk
Suite: $DIST
Codename: $DIST
Version: $LATEST_VERSION
Architectures: amd64 arm64 armhf
Components: $COMPONENT
Description: Unofficial APT mirror for RustDesk — $TOTAL_VERSIONS version(s) available
Date: $(date -Ru)
EOF

# Append checksums
for ALGO in MD5Sum SHA1 SHA256 SHA512; do
  echo "$ALGO:" >> "$DISTS_DIR/Release"
  find "$DISTS_DIR/$COMPONENT" -type f | sort | while read -r FILE; do
    REL_PATH="${FILE#$DISTS_DIR/}"
    SIZE=$(stat -c%s "$FILE")
    case "$ALGO" in
      MD5Sum)  SUM=$(md5sum    "$FILE" | awk '{print $1}') ;;
      SHA1)    SUM=$(sha1sum   "$FILE" | awk '{print $1}') ;;
      SHA256)  SUM=$(sha256sum "$FILE" | awk '{print $1}') ;;
      SHA512)  SUM=$(sha512sum "$FILE" | awk '{print $1}') ;;
    esac
    printf " %s %s %s\n" "$SUM" "$SIZE" "$REL_PATH"
  done >> "$DISTS_DIR/Release"
done

# ── GPG signing ───────────────────────────────────────────────────────────────
if [ -n "$GPG_KEY_ID" ]; then
  echo "==> Signing Release with GPG key $GPG_KEY_ID..."

  export GPG_TTY
  GPG_TTY=$(tty 2>/dev/null || true)

  GPGOPTS="--batch --pinentry-mode loopback"
  [ -n "$GPG_PASSPHRASE" ] && GPGOPTS="$GPGOPTS --passphrase-fd 0"

  echo "$GPG_PASSPHRASE" | gpg $GPGOPTS \
    --default-key "$GPG_KEY_ID" --clearsign \
    --output "$DISTS_DIR/InRelease" "$DISTS_DIR/Release"

  echo "$GPG_PASSPHRASE" | gpg $GPGOPTS \
    --default-key "$GPG_KEY_ID" --detach-sign --armor \
    --output "$DISTS_DIR/Release.gpg" "$DISTS_DIR/Release"

  gpg --armor --export "$GPG_KEY_ID" > "$REPO_ROOT/rustdesk-apt.gpg"
  echo "==> Signed successfully."
else
  echo "==> WARNING: Skipping GPG signing (no key configured)."
fi

echo ""
echo "==> Repository build complete. Index summary:"
for APT_ARCH in amd64 arm64 armhf; do
  PKG_FILE="$DISTS_DIR/$COMPONENT/binary-$APT_ARCH/Packages"
  if [ -f "$PKG_FILE" ]; then
    COUNT=$(grep -c '^Package:' "$PKG_FILE" || echo 0)
    echo "   $APT_ARCH: $COUNT package(s)"
  else
    echo "   $APT_ARCH: (no index)"
  fi
done