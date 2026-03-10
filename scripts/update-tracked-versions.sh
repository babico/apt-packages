#!/usr/bin/env bash
# update-tracked-versions.sh — Merge newly-fetched versions into tracked_versions.json.
# tracked_versions.json is a JSON array of objects:
#   { "version": "1.4.6", "added_at": "2026-03-07T12:00:00Z", "archs": ["amd64","arm64","armhf"] }
set -euo pipefail

VERSIONS_JSON="${1:?Usage: $0 '<json-array-of-versions>'}"
TRACKING_FILE="tracked_versions.json"
POOL_DIR="docs/pool/main/r/rustdesk"

NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Initialise file if it doesn't exist
if [ ! -f "$TRACKING_FILE" ]; then
  echo "[]" > "$TRACKING_FILE"
fi

echo "==> Updating $TRACKING_FILE..."

# Process each version
echo "$VERSIONS_JSON" | jq -r '.[]' | while read -r VERSION; do
  # Determine which archs actually landed in the pool for this version
  ARCHS="[]"
  [ -f "$POOL_DIR/rustdesk-${VERSION}-x86_64.deb"       ] && ARCHS=$(echo "$ARCHS" | jq '. + ["amd64"]')
  [ -f "$POOL_DIR/rustdesk-${VERSION}-aarch64.deb"      ] && ARCHS=$(echo "$ARCHS" | jq '. + ["arm64"]')
  [ -f "$POOL_DIR/rustdesk-${VERSION}-armv7-sciter.deb" ] && ARCHS=$(echo "$ARCHS" | jq '. + ["armhf"]')

  # Fetch release date from GitHub API (best-effort, no auth needed for public repos)
  RELEASE_DATE=$(curl -sSf \
    "https://api.github.com/repos/rustdesk/rustdesk/releases/tags/${VERSION}" \
    2>/dev/null | jq -r '.published_at // empty' || echo "")
  [ -z "$RELEASE_DATE" ] && RELEASE_DATE="$NOW"

  echo "  [track] $VERSION  archs=$(echo "$ARCHS" | jq -r 'join(",")')  released=$RELEASE_DATE"

  # Upsert: remove existing entry for this version (if any), then append fresh one
  ENTRY=$(jq -n \
    --arg v "$VERSION" \
    --arg a "$NOW" \
    --arg r "$RELEASE_DATE" \
    --argjson archs "$ARCHS" \
    '{"version":$v,"added_at":$a,"released_at":$r,"archs":$archs}')

  TMP=$(mktemp)
  jq --argjson entry "$ENTRY" \
    'map(select(.version != $entry.version)) + [$entry]
     | sort_by(.version) | reverse' \
    "$TRACKING_FILE" > "$TMP"
  mv "$TMP" "$TRACKING_FILE"
done

TOTAL=$(jq 'length' "$TRACKING_FILE")
echo "==> tracked_versions.json updated — $TOTAL version(s) tracked total."