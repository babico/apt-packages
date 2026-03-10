#!/usr/bin/env bash
# update-tracked-versions.sh — Upsert newly fetched versions into tracked_versions.json.
# Format: [ { "version":"1.4.6", "released_at":"2026-03-05", "added_at":"...", "archs":["amd64",...] } ]
set -euo pipefail

VERSIONS_JSON="${1:?Usage: $0 '<json-array>'}"
FILE="tracked_versions.json"
POOL="docs/pool/main/r/rustdesk"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

[ -f "$FILE" ] || echo "[]" > "$FILE"

echo "==> Updating $FILE..."

echo "$VERSIONS_JSON" | jq -r '.[]' | while read -r V; do
  # Detect which archs are actually in the pool for this version
  ARCHS="[]"
  [ -f "$POOL/rustdesk-${V}-x86_64.deb"       ] && ARCHS=$(echo "$ARCHS" | jq '. + ["amd64"]')
  [ -f "$POOL/rustdesk-${V}-aarch64.deb"      ] && ARCHS=$(echo "$ARCHS" | jq '. + ["arm64"]')
  [ -f "$POOL/rustdesk-${V}-armv7-sciter.deb" ] && ARCHS=$(echo "$ARCHS" | jq '. + ["armhf"]')

  # Try to get the upstream release date (best-effort, no token needed for public repo)
  REL_DATE=$(curl -sSf \
    "https://api.github.com/repos/rustdesk/rustdesk/releases/tags/${V}" \
    2>/dev/null | jq -r '.published_at // empty' || true)
  [ -z "$REL_DATE" ] && REL_DATE="$NOW"

  echo "  [track] $V  archs=$(echo "$ARCHS" | jq -r 'join(",")' )  released=$REL_DATE"

  ENTRY=$(jq -n \
    --arg  v  "$V"        \
    --arg  a  "$NOW"      \
    --arg  r  "$REL_DATE" \
    --argjson archs "$ARCHS" \
    '{"version":$v,"released_at":$r,"added_at":$a,"archs":$archs}')

  TMP=$(mktemp)
  jq --argjson e "$ENTRY" \
    'map(select(.version != $e.version)) + [$e] | sort_by(.version) | reverse' \
    "$FILE" > "$TMP"
  mv "$TMP" "$FILE"
done

echo "==> tracked_versions.json now has $(jq 'length' "$FILE") entries."