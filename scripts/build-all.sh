#!/usr/bin/env bash
# build-all.sh — Single orchestrator for all package builds.
# Walks .github/build/*/ to detect versions, download, and build.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../.github/build"
TRACK_DIR="$SCRIPT_DIR/../tracked"
POOL_DIR="$SCRIPT_DIR/../docs/pool/main"
SCOOP_DIR="$SCRIPT_DIR/../bucket"
BREW_DIR="$SCRIPT_DIR/../Formula"
NOW=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GH_TOKEN="${GH_TOKEN:-}"
FORCE="${1:-}"
PY="$SCRIPT_DIR/yaml-get.py"

yget() { python3 "$PY" "$@"; }

resolve_url() {
  local url="$1" ver="$2" suffix="$3"
  echo "$url" | sed "s|\${VERSION}|$ver|g; s|\${SUFFIX}|$suffix|g"
}

get_tracked() {
  local f="$TRACK_DIR/$1.json"
  [ -f "$f" ] && jq -r '.[].version' "$f" 2>/dev/null || true
}

upsert_version() {
  local name="$1" ver="$2" rel_date="${3:-$NOW}"
  local f="$TRACK_DIR/${name}.json"
  mkdir -p "$TRACK_DIR"
  [ -f "$f" ] || echo "[]" > "$f"
  local archs_json
  archs_json=$(detect_archs_in_pool "$name" "$ver")
  local entry
  entry=$(jq -n --arg v "$ver" --arg a "$NOW" --arg r "$rel_date" --argjson archs "$archs_json" \
    '{"version":$v,"released_at":$r,"added_at":$a,"archs":$archs}')
  local tmp
  tmp=$(mktemp)
  jq --argjson e "$entry" 'map(select(.version != $e.version)) + [$e] | sort_by(.version) | reverse' "$f" > "$tmp"
  mv "$tmp" "$f"
  echo "    [track] $ver archs=$(echo "$archs_json" | jq -r 'join(",")')"
}

detect_archs_in_pool() {
  local product="$1" ver="$2"
  local config="$BUILD_DIR/$product/config.yml"
  local pool_letter
  pool_letter=$(yget "$config" pool_letter)
  local a_json="[]"
  local pool_path="$POOL_DIR/$pool_letter/$product"
  for bf in "$BUILD_DIR/$product"/deb-*.yml; do
    [ -f "$bf" ] || continue
    local arch
    arch=$(yget "$bf" arch)
    if ls "$pool_path"/*_${arch}.deb >/dev/null 2>&1; then
      a_json=$(echo "$a_json" | jq --arg a "$arch" '. + [$a]')
    fi
  done
  echo "$a_json"
}

get_release_date() {
  local product="$1" ver="$2"
  local config="$BUILD_DIR/$product/config.yml"
  local source repo prefix
  source=$(yget "$config" source)
  repo=$(yget "$config" repo)
  prefix=$(yget "$config" version_prefix)
  local rel=""
  if [ "$source" = "github" ] && [ -n "$repo" ]; then
    rel=$(curl -sSf "https://api.github.com/repos/${repo}/releases/tags/${prefix}${ver}" \
      2>/dev/null | jq -r '.published_at // empty' || true)
  fi
  if [ -z "$rel" ]; then
    local dl_url first_suffix
    first_suffix=""
    for bf in "$BUILD_DIR/$product"/deb-*.yml "$BUILD_DIR/$product"/dmg-*.yml "$BUILD_DIR/$product"/rpm*.yml; do
      [ -f "$bf" ] || continue
      first_suffix=$(yget "$bf" suffix)
      break
    done
    [ -z "$first_suffix" ] && { echo "$NOW"; return; }
    dl_url=$(for fb in "$BUILD_DIR/$product"/deb-*.yml "$BUILD_DIR/$product"/dmg-*.yml "$BUILD_DIR/$product"/rpm*.yml; do
    [ -f "$fb" ] && { yget "$fb" download_url; break; }
  done)
    [ -z "$dl_url" ] && { echo "$NOW"; return; }
    dl_url=$(resolve_url "$dl_url" "$ver" "$first_suffix")
    rel=$(curl -sSI "$dl_url" 2>/dev/null | grep -i '^Last-Modified:' | sed 's/Last-Modified: *//;s/\r//' || true)
    if [ -n "$rel" ]; then
      rel=$(date -u -d "$rel" +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || echo "$NOW")
    fi
  fi
  echo "${rel:-$NOW}"
}

# ── Version detection ─────────────────────────────────────────────────

detect_version() {
  local product="$1"
  local config="$BUILD_DIR/$product/config.yml"
  local source name repo lurl vre prefix extract_re
  source=$(yget "$config" source)
  name=$(yget "$config" name)

  case "$source" in
    github)
      repo=$(yget "$config" repo)
      prefix=$(yget "$config" version_prefix)
      local tag
      tag=$(curl -sSf -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" \
        "https://api.github.com/repos/${repo}/releases/latest" | jq -r '.tag_name')
      echo "${tag#$prefix}"
      ;;
    http_listing)
      lurl=$(yget "$config" listing_url)
      local vre
      vre=$(yget "$config" version_match)
      # grep for matching lines, extract version with sed capture group
      local matches
      matches=$(curl -sSf "$lurl" | grep -oP "$vre" || true)
      # Extract the version from each match using the capture group
      echo "$matches" | sed -E 's/.*([0-9]+\.[0-9]+(\.[0-9]+)?).*/\1/' | sort -V -u | tail -1
      ;;
    zip_download)
      local suf bf dl_url_tpl suffix_val durl zip_tmp
      bf=$(ls "$BUILD_DIR/$product"/deb-*.yml 2>/dev/null | head -1)
      [ -z "$bf" ] && { echo ""; return; }
      dl_url_tpl=$(yget "$bf" download_url)
      suffix_val=$(yget "$bf" suffix)
      durl=$(echo "$dl_url_tpl" | sed "s|\${SUFFIX}|$suffix_val|g")
      zip_tmp=$(mktemp --suffix=.zip)
      curl -sSf "$durl" -o "$zip_tmp" || true
      ver=$(unzip -l "$zip_tmp" 2>/dev/null | grep -oP '[0-9]+\.[0-9]+\.[0-9]+' | head -1 || true)
      rm -f "$zip_tmp"
      echo "$ver"
      ;;
    *)
      echo ""
      ;;
  esac
}

# ── Download ──────────────────────────────────────────────────────────

download() {
  local product="$1" version="$2"
  local config="$BUILD_DIR/$product/config.yml"
  local pool_letter
  pool_letter=$(yget "$config" pool_letter)
  local pool_path="$POOL_DIR/$pool_letter/$product"
  mkdir -p "$pool_path"

  local ok=0
  for bf in "$BUILD_DIR/$product"/deb-*.yml "$BUILD_DIR/$product"/rpm*.yml; do
    [ -f "$bf" ] || continue
    local format arch suffix dl_url_tpl
    format=$(yget "$bf" format)
    arch=$(yget "$bf" arch)
    suffix=$(yget "$bf" suffix)
    dl_url_tpl=$(yget "$bf" download_url)

    case "$format" in
      deb)
        local extract
        extract=$(yget "$bf" extract)
        extract=$(echo "$extract" | tr '[:upper:]' '[:lower:]')
        local dl_url
        dl_url=$(resolve_url "$dl_url_tpl" "$version" "$suffix")

        if [ "$extract" = "true" ]; then
          local zip_tmp
          zip_tmp="$pool_path/${suffix}.zip.tmp"
          echo "    [fetch] $suffix ($arch) via zip"
          local http
          http=$(curl -sSL -w "%{http_code}" -o "$zip_tmp" "$dl_url")
          if [ "$http" = "200" ]; then
            local extract_dir inner_deb inner_name
            extract_dir=$(mktemp -d)
            unzip -q "$zip_tmp" -d "$extract_dir"
            inner_deb=$(find "$extract_dir" -name '*.deb' | head -1)
            if [ -f "$inner_deb" ]; then
              inner_name=$(basename "$inner_deb")
              cp "$inner_deb" "$pool_path/$inner_name"
              echo "    [ok]    $inner_name ($(du -sh "$pool_path/$inner_name" | cut -f1))"
              ((ok++)) || true
            else
              echo "    [error] no .deb in zip"
            fi
            rm -rf "$extract_dir"
          else
            echo "    [miss]  $suffix — HTTP $http"
          fi
          rm -f "$zip_tmp"
        else
          local pool_name
          pool_name=$(echo "$(yget "$bf" pool_name)" | sed "s|\${VERSION}|$version|g")
          local dest="$pool_path/$pool_name"
          if [ -f "$dest" ]; then
            echo "    [skip]  $pool_name"
            ((ok++)) || true
            continue
          fi
          echo "    [fetch] $pool_name"
          local http
          http=$(curl -sSL -w "%{http_code}" -o "${dest}.tmp" "$dl_url")
          if [ "$http" = "200" ]; then
            mv "${dest}.tmp" "$dest"
            echo "    [ok]    $pool_name ($(du -sh "$dest" | cut -f1))"
            ((ok++)) || true
          else
            rm -f "${dest}.tmp"
            echo "    [miss]  $pool_name — HTTP $http"
          fi
        fi
        ;;

      rpm)
        if [ "$product" = "apidog" ]; then
          echo "    [rpm]  Building from tarball..."
          local rurl spec_tmpl
          rurl=$(resolve_url "$dl_url_tpl" "$version" "$suffix")
          spec_tmpl="$BUILD_DIR/$product/rpm.spec.tmpl"
          local rpm_root
          rpm_root=$(mktemp -d)
          mkdir -p "$rpm_root"/{BUILD,RPMS,SOURCES,SPECS,SRPMS}
          curl -sSf "$rurl" -o "$rpm_root/SOURCES/apidog-manual.tar.gz"
          local changelog
          changelog="* $(date -u +'%a %b %d %Y') Apidog Build - ${version}-1\n- Automated build from upstream tarball"
          sed -e "s/__VERSION__/$version/g" -e "s|__CHANGELOG__|$changelog|g" \
            "$spec_tmpl" > "$rpm_root/SPECS/apidog.spec"
          (cd "$rpm_root" && rpmbuild -ba --define "_topdir $PWD" SPECS/apidog.spec 2>&1 | tail -3) || true
          local rpm_file
          rpm_file=$(find "$rpm_root/RPMS" -name "*.rpm" 2>/dev/null | head -1)
          if [ -f "$rpm_file" ]; then
            cp "$rpm_file" "$pool_path/$(basename "$rpm_file")"
            echo "    [ok]    $(basename "$rpm_file") ($(du -sh "$rpm_file" | cut -f1))"
            ((ok++)) || true
          else
            echo "    [error] rpmbuild failed"
          fi
          rm -rf "$rpm_root"
        fi
        ;;
    esac
  done
  [ "$ok" -gt 0 ] && return 0 || return 1
}

# ── Scoop manifest builder ────────────────────────────────────────────

build_scoop() {
  local product="$1" version="$2"
  local tmpl="$BUILD_DIR/$product/scoop.json.tmpl"
  [ -f "$tmpl" ] || return 0

  local config="$BUILD_DIR/$product/config.yml"
  local source repo prefix lurl product_name
  source=$(yget "$config" source)
  repo=$(yget "$config" repo)
  prefix=$(yget "$config" version_prefix)
  lurl=$(yget "$config" listing_url)
  product_name=$(yget "$config" name)

  local url64="" hash64="" url32="" hash32=""

  case "$source" in
    github)
      local assets win_asset win_name
      assets=$(curl -sSf -H "Accept: application/vnd.github+json" -H "Authorization: Bearer $GH_TOKEN" \
        "https://api.github.com/repos/${repo}/releases/latest")
      win_name=$(echo "$assets" | jq -r \
        '[.assets[] | select(.name | test("\\.(exe|msi|zip)$"; "i")) | select(.name | test("win|x86|x64|amd64|arm64"; "i")) | select(.name | test("blockmap"; "i") | not)] |
         (map(select(.name | endswith(".msi"))) | .[0].name // empty) //
         (map(select(.name | endswith(".exe"))) | .[0].name // empty) //
         (map(select(.name | endswith(".zip"))) | .[0].name // empty)')
      url64=$(echo "$assets" | jq -r --arg n "$win_name" '.assets[] | select(.name == $n) | .browser_download_url')
      hash64=$(curl -sSf "$url64" | sha256sum | awk '{print $1}')
      ;;
    http_listing)
      local sf
      sf=$(ls "$BUILD_DIR/$product"/scoop.yml 2>/dev/null | head -1)
      local dl_tpl
      dl_tpl=$(yget "$sf" download_url 2>/dev/null || echo "")
      [ -z "$dl_tpl" ] && dl_tpl="https://download.tixati.com/tixati-\${VERSION}-1.win64-install.exe"
      url64=$(echo "$dl_tpl" | sed "s|\${VERSION}|$version|g; s|\${SUFFIX}|win64-install.exe|g")
      hash64=$(curl -sSf "$url64" | sha256sum | awk '{print $1}')
      ;;
    zip_download)
      local sf suf64 suf32 dl_tpl
      sf="$BUILD_DIR/$product/scoop.yml"
      dl_tpl=$(yget "$sf" download_url)
      suf64=$(yget "$sf" suffix_64)
      suf32=$(yget "$sf" suffix_32)
      url64=$(echo "$dl_tpl" | sed "s|\${SUFFIX}|$suf64|g")
      hash64=$(curl -sSf "$url64" | sha256sum | awk '{print $1}')
      if [ -n "$suf32" ]; then
        url32=$(echo "$dl_tpl" | sed "s|\${SUFFIX}|$suf32|g")
        hash32=$(curl -sSf "$url32" | sha256sum | awk '{print $1}')
      fi
      ;;
  esac

  mkdir -p "$SCOOP_DIR"
  local out
  out=$(cat "$tmpl")
  out=$(echo "$out" | sed "s|\${VERSION}|$version|g")
  out=$(echo "$out" | sed "s|\${SHA256_64}|$hash64|g")
  out=$(echo "$out" | sed "s|\${SHA256_32}|$hash32|g")
  out=$(echo "$out" | sed "s|\${SHA256}|$hash64|g")
  echo "$out" > "$SCOOP_DIR/${product_name}.json"
  echo "    [scoop] updated"
}

# ── Homebrew formula builder ──────────────────────────────────────────

build_brew() {
  local product="$1" version="$2"
  local tmpl="$BUILD_DIR/$product/brew.rb.tmpl"
  [ -f "$tmpl" ] || return 0

  local config="$BUILD_DIR/$product/config.yml"
  local product_name
  product_name=$(yget "$config" name)
  local mac_arm_url="" mac_arm_hash=""
  local mac_x86_url="" mac_x86_hash=""
  local lin_arm_url="" lin_arm_hash=""
  local lin_amd64_url="" lin_amd64_hash=""
  local lin_rpm_url="" lin_rpm_hash=""

  for bf in "$BUILD_DIR/$product"/*.yml; do
    [ -f "$bf" ] || continue
    [ "$(basename "$bf")" = "config.yml" ] && continue
    local fmt arch dl_tpl suffix
    fmt=$(yget "$bf" format)
    arch=$(yget "$bf" arch)
    dl_tpl=$(yget "$bf" download_url)
    suffix=$(yget "$bf" suffix)

    case "$fmt:$arch" in
      dmg:arm)
        mac_arm_url=$(resolve_url "$dl_tpl" "$version" "$suffix")
        mac_arm_hash=$(curl -sSf "$mac_arm_url" | sha256sum | awk '{print $1}')
        ;;
      dmg:x86)
        mac_x86_url=$(resolve_url "$dl_tpl" "$version" "$suffix")
        mac_x86_hash=$(curl -sSf "$mac_x86_url" | sha256sum | awk '{print $1}')
        ;;
      deb:arm64|deb:armhf)
        lin_arm_url=$(resolve_url "$dl_tpl" "$version" "$suffix")
        lin_arm_hash=$(curl -sSf "$lin_arm_url" | sha256sum | awk '{print $1}')
        ;;
      deb:amd64)
        lin_amd64_url=$(resolve_url "$dl_tpl" "$version" "$suffix")
        lin_amd64_hash=$(curl -sSf "$lin_amd64_url" | sha256sum | awk '{print $1}')
        ;;
      rpm:x86)
        lin_rpm_url=$(resolve_url "$dl_tpl" "$version" "$suffix")
        lin_rpm_hash=$(curl -sSf "$lin_rpm_url" | sha256sum | awk '{print $1}')
        ;;
    esac
  done

  mkdir -p "$BREW_DIR"
  local out
  out=$(cat "$tmpl")
  out=$(echo "$out" | sed "s|\${VERSION}|$version|g")
  out=$(echo "$out" | sed "s|\${MAC_ARM_URL}|$mac_arm_url|g")
  out=$(echo "$out" | sed "s|\${MAC_ARM_SHA256}|$mac_arm_hash|g")
  out=$(echo "$out" | sed "s|\${MAC_X86_URL}|$mac_x86_url|g")
  out=$(echo "$out" | sed "s|\${MAC_X86_SHA256}|$mac_x86_hash|g")
  out=$(echo "$out" | sed "s|\${LINUX_ARM_URL}|$lin_arm_url|g")
  out=$(echo "$out" | sed "s|\${LINUX_ARM_SHA256}|$lin_arm_hash|g")
  out=$(echo "$out" | sed "s|\${LINUX_AMD64_URL}|$lin_amd64_url|g")
  out=$(echo "$out" | sed "s|\${LINUX_AMD64_SHA256}|$lin_amd64_hash|g")
  out=$(echo "$out" | sed "s|\${LINUX_RPM_URL}|$lin_rpm_url|g")
  out=$(echo "$out" | sed "s|\${LINUX_RPM_SHA256}|$lin_rpm_hash|g")
  echo "$out" > "$BREW_DIR/${product_name}.rb"
  echo "    [brew]  updated"
}

# ── Main ──────────────────────────────────────────────────────────────

main() {
  echo "==> Scanning build targets..."
  local any_update=false

  for dir in "$BUILD_DIR"/*/; do
    local product
    product=$(basename "$dir")
    local config="$dir/config.yml"
    [ -f "$config" ] || continue

    local name
    name=$(yget "$config" name)
    echo ""
    echo "--- $name ---"

    local latest
    latest=$(detect_version "$product")
    [ -z "$latest" ] && { echo "  [skip]  version detection failed"; continue; }
    echo "  upstream: $latest"

    local tracked
    tracked=$(get_tracked "$name")
    if echo "$tracked" | grep -qx "$latest" && [ "$FORCE" != "force" ]; then
      echo "  already at $latest"
      continue
    fi

    echo "  => queued: $latest"
    any_update=true

    # Download .deb / build .rpm
    download "$product" "$latest"

    # Build Scoop manifest
    build_scoop "$product" "$latest"

    # Build Homebrew formula + track version
    build_brew "$product" "$latest"

    # Track for APT
    local rel_date
    rel_date=$(get_release_date "$product" "$latest")
    upsert_version "$name" "$latest" "$rel_date"
  done

  if [ "$any_update" = "true" ] || [ "$FORCE" = "rebuild" ]; then
    echo ""
    echo "==> Rebuilding APT index..."
    bash "$SCRIPT_DIR/build-apt.sh" "${GPG_KEY_ID:-}" "${GPG_PASSPHRASE:-}"

    echo "==> Generating landing page..."
    bash "$SCRIPT_DIR/build-index.sh"

    echo "==> Committing..."
    git config user.name "github-actions[bot]"
    git config user.email "github-actions[bot]@users.noreply.github.com"
    git pull --rebase origin main || true
    git add -A tracked/
    git add -A docs/dists/ docs/index.html docs/apt-repo.gpg 2>/dev/null || true
    git add -A bucket/ Formula/
    git add -A .github/build/
    git commit -m "chore: update packages" || echo "Nothing to commit"
    git push
  else
    echo ""
    echo "No updates needed."
  fi
}

main