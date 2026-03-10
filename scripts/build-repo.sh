#!/usr/bin/env bash
# build-repo.sh — Build a full APT repository index from ALL .deb files in the pool.
# Every version present in docs/pool/ is indexed and available to apt.
set -euo pipefail

LATEST="${1:?Usage: $0 <latest_version> [gpg_key_id] [gpg_passphrase]}"
GPG_KEY_ID="${2:-}"
GPG_PASSPHRASE="${3:-}"

REPO_ROOT="docs"
DIST="stable"
COMP="main"
POOL="$REPO_ROOT/pool/$COMP/r/rustdesk"
DISTS="$REPO_ROOT/dists/$DIST"

echo "==> Building APT index from pool (all versions)..."

# Count versions
VERSIONS_IN_POOL=$(find "$POOL" -name '*.deb' 2>/dev/null \
  | sed 's|.*rustdesk-||;s|-[^-]*\.deb$||' | sort -uV | tr '\n' ' ')
echo "    Versions in pool: ${VERSIONS_IN_POOL:-none}"

# Clean stale index
rm -rf "$DISTS"
mkdir -p "$DISTS/$COMP"

# ── Per-architecture Packages files ──────────────────────────────────────────
# We hard-link each arch's debs into a temp staging tree so dpkg-scanpackages
# sees only the right files. The Filename: entries will then be correct relative
# to docs/ when we strip the staging prefix below.

declare -A ARCH_SUFFIX=(
  [amd64]="x86_64.deb"
  [arm64]="aarch64.deb"
  [armhf]="armv7-sciter.deb"
)

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

for ARCH in "${!ARCH_SUFFIX[@]}"; do
  SUFFIX="${ARCH_SUFFIX[$ARCH]}"
  STAGE_POOL="$STAGING/$ARCH/pool/$COMP/r/rustdesk"
  mkdir -p "$STAGE_POOL"

  # Link matching debs into the staging pool
  while IFS= read -r -d '' DEB; do
    ln "$DEB" "$STAGE_POOL/$(basename "$DEB")" 2>/dev/null \
      || cp "$DEB" "$STAGE_POOL/$(basename "$DEB")"
  done < <(find "$POOL" -name "*-${SUFFIX}" -print0 2>/dev/null)

  COUNT=$(find "$STAGE_POOL" -name '*.deb' | wc -l)
  if [ "$COUNT" -eq 0 ]; then
    echo "  [skip] $ARCH — no packages"
    continue
  fi

  PKG_DIR="$DISTS/$COMP/binary-$ARCH"
  mkdir -p "$PKG_DIR"

  # Scan from staging root → Filename paths will be pool/...
  (cd "$STAGING/$ARCH" && \
    dpkg-scanpackages "pool/$COMP/r/rustdesk" /dev/null 2>/dev/null) \
    > "$PKG_DIR/Packages"

  # Fix Filename: paths — they must be relative to the GitHub Pages root (docs/),
  # so prepend nothing (dpkg-scanpackages already emits "pool/..." which is correct
  # because GitHub Pages serves docs/ as the root).
  # Verify the paths look right:
  FIRST=$(grep '^Filename:' "$PKG_DIR/Packages" | head -1)
  echo "  [ok]  $ARCH — $COUNT pkg(s)  ($FIRST)"

  gzip -9 -k -f "$PKG_DIR/Packages"
done

# ── Release file ──────────────────────────────────────────────────────────────
echo "==> Generating Release..."

OWNER="${GITHUB_REPOSITORY_OWNER:-your-username}"
SLUG="${GITHUB_REPOSITORY:-your-username/rustdesk-repo}"
TOTAL=$(find "$POOL" -name '*.deb' 2>/dev/null \
  | sed 's|.*rustdesk-||;s|-[^-]*\.deb$||' | sort -uV | wc -l || echo "?")

cat > "$DISTS/Release" <<RELEASE
Origin: RustDesk APT Mirror
Label: RustDesk
Suite: $DIST
Codename: $DIST
Version: $LATEST
Architectures: amd64 arm64 armhf
Components: $COMP
Description: Unofficial APT mirror — $TOTAL version(s) available
Date: $(date -Ru)
RELEASE

for ALGO in MD5Sum SHA1 SHA256 SHA512; do
  echo "$ALGO:" >> "$DISTS/Release"
  find "$DISTS/$COMP" -type f | sort | while read -r F; do
    REL="${F#$DISTS/}"
    SZ=$(stat -c%s "$F")
    case "$ALGO" in
      MD5Sum)  SUM=$(md5sum    "$F" | awk '{print $1}') ;;
      SHA1)    SUM=$(sha1sum   "$F" | awk '{print $1}') ;;
      SHA256)  SUM=$(sha256sum "$F" | awk '{print $1}') ;;
      SHA512)  SUM=$(sha512sum "$F" | awk '{print $1}') ;;
    esac
    printf " %s %s %s\n" "$SUM" "$SZ" "$REL"
  done >> "$DISTS/Release"
done

# ── GPG sign ──────────────────────────────────────────────────────────────────
if [ -n "$GPG_KEY_ID" ]; then
  echo "==> Signing with key $GPG_KEY_ID..."
  export GPG_TTY; GPG_TTY=$(tty 2>/dev/null || true)
  OPTS="--batch --pinentry-mode loopback"
  [ -n "$GPG_PASSPHRASE" ] && OPTS="$OPTS --passphrase-fd 0"

  echo "$GPG_PASSPHRASE" | gpg $OPTS --default-key "$GPG_KEY_ID" \
    --clearsign  --output "$DISTS/InRelease"  "$DISTS/Release"
  echo "$GPG_PASSPHRASE" | gpg $OPTS --default-key "$GPG_KEY_ID" \
    --detach-sign --armor --output "$DISTS/Release.gpg" "$DISTS/Release"
  gpg --armor --export "$GPG_KEY_ID" > "$REPO_ROOT/rustdesk-apt.gpg"
  echo "==> Signed OK."
else
  echo "==> No GPG key — skipping signatures."
fi

echo ""
echo "==> Index summary:"
for ARCH in amd64 arm64 armhf; do
  F="$DISTS/$COMP/binary-$ARCH/Packages"
  [ -f "$F" ] && echo "   $ARCH: $(grep -c '^Package:' "$F") package(s)" || echo "   $ARCH: (none)"
done