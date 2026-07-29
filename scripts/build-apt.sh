#!/usr/bin/env bash
# build-apt.sh — Build APT repository index from pool.
# Reads .github/build/*/config.yml and deb-*.yml for app metadata.
set -euo pipefail

GPG_KEY_ID="${1:-}"
GPG_PASSPHRASE="${2:-}"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../.github/build"
REPO_ROOT="docs"
DIST="stable"
COMP="main"
POOL="$REPO_ROOT/pool/$COMP"
DISTS="$REPO_ROOT/dists/$DIST"
PY="$SCRIPT_DIR/yaml-get.py"

yget() { python3 "$PY" "$@"; }

echo "==> Building APT index from pool (all apps, all versions)..."

ALL_ARCHS=""
for dir in "$BUILD_DIR"/*/; do
  for bf in "$dir"deb-*.yml; do
    [ -f "$bf" ] || continue
    arch=$(yget "$bf" arch 2>/dev/null || true)
    [ -n "$arch" ] && ALL_ARCHS="$ALL_ARCHS $arch"
  done
done
ALL_ARCHS=$(echo "$ALL_ARCHS" | tr ' ' '\n' | sort -u | tr '\n' ' ')
echo "    Architectures: $ALL_ARCHS"

TOTAL_DEBS=$(find "$POOL" -name '*.deb' 2>/dev/null | wc -l || echo 0)
echo "    Total .deb files in pool: $TOTAL_DEBS"

rm -rf "$DISTS"
mkdir -p "$DISTS/$COMP"

STAGING=$(mktemp -d)
trap 'rm -rf "$STAGING"' EXIT

for ARCH in $ALL_ARCHS; do
  STAGE_POOL="$STAGING/$ARCH/pool/$COMP"
  mkdir -p "$STAGE_POOL"

  for dir in "$BUILD_DIR"/*/; do
    [ -f "$dir/config.yml" ] || continue
    local name pool_letter suffix
    name=$(yget "$dir/config.yml" name)
    pool_letter=$(yget "$dir/config.yml" pool_letter)
    suffix=""

    for bf in "$dir"deb-*.yml; do
      [ -f "$bf" ] || continue
      local bf_arch
      bf_arch=$(yget "$bf" arch)
      if [ "$bf_arch" = "$ARCH" ]; then
        suffix=$(yget "$bf" suffix)
        break
      fi
    done
    [ -z "$suffix" ] && continue

    SRC_POOL="$POOL/${pool_letter}/${name}"
    [ -d "$SRC_POOL" ] || continue

    STAGE_APP="$STAGE_POOL/${pool_letter}/${name}"
    mkdir -p "$STAGE_APP"

    while IFS= read -r -d '' DEB; do
      ln "$DEB" "$STAGE_APP/$(basename "$DEB")" 2>/dev/null \
        || cp "$DEB" "$STAGE_APP/$(basename "$DEB")"
    done < <(find "$SRC_POOL" -name "*${suffix}" -print0 2>/dev/null)
  done

  COUNT=$(find "$STAGE_POOL" -name '*.deb' 2>/dev/null | wc -l)
  if [ "$COUNT" -eq 0 ]; then
    echo "  [skip] $ARCH — no packages"
    continue
  fi

  PKG_DIR="$DISTS/$COMP/binary-$ARCH"
  mkdir -p "$PKG_DIR"

  (cd "$STAGING/$ARCH" && \
    dpkg-scanpackages "pool/$COMP" /dev/null 2>/dev/null) \
    > "$PKG_DIR/Packages"

  FIRST=$(grep '^Filename:' "$PKG_DIR/Packages" | head -1)
  echo "  [ok]  $ARCH — $COUNT pkg(s)  ($FIRST)"
  gzip -9 -k -f "$PKG_DIR/Packages"
done

echo "==> Generating Release..."

OWNER="${GITHUB_REPOSITORY_OWNER:-babico}"
SLUG="${GITHUB_REPOSITORY:-babico/packages}"

APP_COUNT=0
for dir in "$BUILD_DIR"/*/; do
  [ -f "$dir/config.yml" ] && APP_COUNT=$((APP_COUNT + 1))
done

TOTAL_VERSIONS=0
for dir in "$BUILD_DIR"/*/; do
  [ -f "$dir/config.yml" ] || continue
  name=$(yget "$dir/config.yml" name)
  tf="tracked_versions/${name}.json"
  if [ -f "$tf" ]; then
    vc=$(jq 'length' "$tf" 2>/dev/null || echo 0)
    TOTAL_VERSIONS=$((TOTAL_VERSIONS + vc))
  fi
done

cat > "$DISTS/Release" <<RELEASE
Origin: Personal APT Mirror
Label: Personal APT Repository
Suite: $DIST
Codename: $DIST
Architectures: $(echo $ALL_ARCHS | tr ' ' ' ')
Components: $COMP
Description: Personal APT mirror — $APP_COUNT app(s), $TOTAL_VERSIONS version(s) available
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

if [ -n "$GPG_KEY_ID" ]; then
  echo "==> Signing with key $GPG_KEY_ID..."
  export GPG_TTY; GPG_TTY=$(tty 2>/dev/null || true)
  OPTS="--batch --pinentry-mode loopback"
  [ -n "$GPG_PASSPHRASE" ] && OPTS="$OPTS --passphrase-fd 0"

  echo "$GPG_PASSPHRASE" | gpg $OPTS --default-key "$GPG_KEY_ID" \
    --clearsign  --output "$DISTS/InRelease"  "$DISTS/Release"
  echo "$GPG_PASSPHRASE" | gpg $OPTS --default-key "$GPG_KEY_ID" \
    --detach-sign --armor --output "$DISTS/Release.gpg" "$DISTS/Release"
  gpg --armor --export "$GPG_KEY_ID" > "$REPO_ROOT/apt-repo.gpg"
  echo "==> Signed OK."
else
  echo "==> No GPG key — skipping signatures."
fi

echo ""
echo "==> Index summary:"
for ARCH in $ALL_ARCHS; do
  F="$DISTS/$COMP/binary-$ARCH/Packages"
  [ -f "$F" ] && echo "   $ARCH: $(grep -c '^Package:' "$F") package(s)" || echo "   $ARCH: (none)"
done