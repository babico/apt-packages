#!/usr/bin/env bash
# build-index.sh — Generate HTML landing page from .github/build/*/ configs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../.github/build"
TRACK_DIR="$SCRIPT_DIR/../tracked_versions"
PY="$SCRIPT_DIR/yaml-get.py"

yget() { python3 "$PY" "$@"; }

OWNER="${GITHUB_REPOSITORY_OWNER:-babico}"
SLUG="${GITHUB_REPOSITORY:-babico/packages}"
NAME="${SLUG##*/}"
URL="https://${OWNER}.github.io/${NAME}"
UPDATED=$(date -u '+%Y-%m-%d %H:%M UTC')

mkdir -p docs

APP_COUNT=0
TOTAL_VERSIONS=0

APP_SECTIONS=""
APP_NAV=""

for dir in "$BUILD_DIR"/*/; do
  config="$dir/config.yml"
  [ -f "$config" ] || continue
  APP_COUNT=$((APP_COUNT + 1))

  app_name=$(yget "$config" name)
  display=$(yget "$config" display)
  description=$(yget "$config" description)
  homepage=$(yget "$config" homepage)
  pool_letter=$(yget "$config" pool_letter)
  github_repo=$(yget "$config" repo)
  license=$(yget "$config" license)
  git_repo="$github_repo"
  version_prefix=$(yget "$config" version_prefix)

  TRACKING="$TRACK_DIR/${app_name}.json"
  ROWS=""
  TOTAL=0
  LATEST=""

  if [ -f "$TRACKING" ]; then
    TOTAL=$(jq 'length' "$TRACKING")
    TOTAL_VERSIONS=$((TOTAL_VERSIONS + TOTAL))
    LATEST=$(jq -r '
      if length == 0 then "" else
        max_by([(.released_at // .added_at // ""),
          ((.version // "") | split(".") | map(tonumber? // 0))
        ]) | .version // "" end' "$TRACKING")

    while IFS= read -r ROW; do
      V=$(echo "$ROW" | jq -r '.version')
      REL=$(echo "$ROW" | jq -r '.released_at // .added_at' | cut -c1-10)
      ARCHS_CSV=$(echo "$ROW" | jq -r '.archs | join(", ")')

      LATEST_BADGE=""
      ROW_CLASS=""
      [ "$V" = "$LATEST" ] && LATEST_BADGE=' <span class="badge-latest">latest</span>' && ROW_CLASS=' class="row-latest"'

      DEB_LINKS=""
      while IFS= read -r ARCH; do
        for bf in "$dir"deb-*.yml; do
          [ -f "$bf" ] || continue
          bf_arch=$(yget "$bf" arch)
          [ "$bf_arch" = "$ARCH" ] || continue
          suffix=$(yget "$bf" suffix)
          pool_name=$(yget "$bf" pool_name 2>/dev/null || echo "")
          if [ -n "$pool_name" ]; then
            pkg=$(echo "$pool_name" | sed "s|\${VERSION}|$V|g")
          else
            pkg="*_${ARCH}.deb"
            pkg=$(ls "docs/pool/main/${pool_letter}/${app_name}/"*_${ARCH}.deb 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "$pkg")
          fi
          DEB_LINKS="${DEB_LINKS}<a class=\"dl\" href=\"${URL}/pool/main/${pool_letter}/${app_name}/${pkg}\">${ARCH}</a>"
          break
        done
      done < <(echo "$ROW" | jq -r '.archs[]')

      tag="${version_prefix}${V}"
      if [ -n "$git_repo" ]; then
        CHANGELOG_LINK="<a class=\"dl\" href=\"https://github.com/${git_repo}/releases/tag/${tag}\" target=\"_blank\" rel=\"noopener\">notes&nbsp;&#8599;</a>"
      else
        CHANGELOG_LINK="<a class=\"dl\" href=\"${homepage}\" target=\"_blank\" rel=\"noopener\">website&nbsp;&#8599;</a>"
      fi

      ROWS="${ROWS}
        <tr${ROW_CLASS}>
          <td><code>${V}</code>${LATEST_BADGE}</td>
          <td>${REL}</td>
          <td><code>${ARCHS_CSV}</code></td>
          <td class=\"dl-cell\">${DEB_LINKS}</td>
          <td>${CHANGELOG_LINK}</td>
        </tr>"
    done < <(jq -c '.[]' "$TRACKING")
  fi

  APP_NAV="${APP_NAV}<a href=\"#${app_name}\" class=\"nav-app\">${display}</a> "
  INSTALL_CMD="sudo apt install ${app_name}"

  if [ -n "$git_repo" ]; then
    RELEASES_LINK="&nbsp;|&nbsp; <a href=\"https://github.com/${git_repo}/releases\">GitHub releases</a>"
  else
    RELEASES_LINK=""
  fi

  APP_SECTIONS="${APP_SECTIONS}
  <section id=\"${app_name}\">
    <h2>&#x1F4E6; ${display}</h2>
    <p>${description} &mdash; <a href=\"${homepage}\">${homepage}</a>
      ${RELEASES_LINK}
      &nbsp;|&nbsp; <strong>${TOTAL} version(s)</strong>$([ -n "$LATEST" ] && echo " &nbsp;|&nbsp; Latest: <code>${LATEST}</code>")</p>

    <div class=\"card\">
      <h3>Install ${display}</h3>
      <pre><code>${INSTALL_CMD}</code></pre>
    </div>

    <h3>All versions (${TOTAL})</h3>
    <input class=\"search\" type=\"search\" placeholder=\"Filter ${display} versions&hellip;\" oninput=\"filterTable(this,'tbody-${app_name}')\" />
    <div class=\"tbl-wrap\">
      <table>
        <thead><tr><th>Version</th><th>Released</th><th>Architectures</th><th>Download .deb</th><th>Changelog</th></tr></thead>
        <tbody id=\"tbody-${app_name}\">${ROWS}</tbody>
      </table>
    </div>
  </section>
  <hr class=\"section-sep\" />"
done

cat > docs/index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Personal APT Repository</title>
  <style>
    :root{--bg:#0d1117;--surface:#161b22;--border:#30363d;--text:#c9d1d9;--muted:#8b949e;--accent:#58a6ff;--green:#3fb950;--yellow:#d29922;--code-bg:#1c2128;--hi:#1c2c3c}
    *{box-sizing:border-box;margin:0;padding:0}
    body{background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;line-height:1.6;padding:2rem 1rem}
    .wrap{max-width:960px;margin:0 auto}
    header{border-bottom:1px solid var(--border);padding-bottom:1.5rem;margin-bottom:2rem}
    h1{font-size:1.75rem;color:#e6edf3}
    h1 em{font-style:normal;color:var(--accent)}
    h2{font-size:1.25rem;color:#e6edf3;margin:2rem 0 .75rem}
    h3{font-size:.95rem;color:#e6edf3;margin:.5rem 0}
    p{color:var(--muted);margin-bottom:.75rem}
    section{margin-bottom:1rem}
    .section-sep{border:none;border-top:1px solid var(--border);margin:2rem 0}
    .card{background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:1.2rem 1.4rem;margin-bottom:1rem}
    pre{background:var(--code-bg);border:1px solid var(--border);border-radius:6px;padding:.85rem 1rem;overflow-x:auto;font-size:.82rem;color:#e6edf3;margin:.35rem 0}
    code{font-family:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace}
    .dim{color:var(--muted)}
    .nav-apps{margin:.75rem 0}
    .nav-app{display:inline-block;padding:.3em .7em;border-radius:6px;margin:.15em;background:var(--surface);border:1px solid var(--border);color:var(--accent);font-size:.85rem;text-decoration:none}
    .nav-app:hover{background:#21262d}
    .step{display:flex;gap:.75rem;align-items:flex-start}
    .num{min-width:1.6rem;height:1.6rem;border-radius:50%;background:var(--accent);color:#fff;display:flex;align-items:center;justify-content:center;font-size:.78rem;font-weight:700;flex-shrink:0;margin-top:.15rem}
    .badge-latest{display:inline-block;padding:.12em .5em;border-radius:2em;font-size:.7rem;font-weight:700;margin-left:.35rem;vertical-align:middle;background:#238636;color:#fff}
    .tbl-wrap{overflow-x:auto;margin-top:.5rem}
    table{width:100%;border-collapse:collapse;font-size:.84rem}
    th{padding:.5rem .7rem;text-align:left;border-bottom:2px solid var(--border);color:var(--muted);font-weight:600}
    td{padding:.45rem .7rem;border-bottom:1px solid var(--border);vertical-align:middle}
    tr.row-latest td{background:var(--hi)}
    tr:hover td{background:#1a2030}
    .dl{display:inline-block;padding:.12em .45em;border-radius:4px;margin:.1em;background:#21262d;border:1px solid var(--border);color:var(--accent);font-size:.78rem;text-decoration:none;white-space:nowrap}
    .dl:hover{background:#30363d}
    .search{width:100%;padding:.5rem .75rem;margin-bottom:.6rem;background:var(--code-bg);border:1px solid var(--border);border-radius:6px;color:var(--text);font-size:.875rem}
    .search::placeholder{color:var(--muted)}
    .warn{background:#2d1f00;border:1px solid #6e4c00;border-radius:6px;padding:.7rem 1rem;margin:.6rem 0;font-size:.875rem;color:#e3b341}
    .info td,.info th{padding:.4rem .7rem;border-bottom:1px solid var(--border);font-size:.875rem}
    .info th{color:var(--muted);font-weight:600}
    footer{margin-top:3rem;padding-top:1.5rem;border-top:1px solid var(--border);font-size:.8rem;color:var(--muted)}
    a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
  </style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>&#x1F5A5; <em>Personal</em> APT Repository</h1>
    <p style="margin-top:.4rem">Unofficial APT mirror &mdash; <strong>${APP_COUNT} app(s)</strong>, <strong>${TOTAL_VERSIONS} version(s)</strong> available. Updated: <strong>${UPDATED}</strong></p>
    <div class="nav-apps">${APP_NAV}</div>
  </header>

  <h2>Quick Setup</h2>
  <div class="card"><div class="step"><div class="num">1</div><div style="width:100%"><h3>Import the signing key</h3><pre><code>curl -fsSL ${URL}/apt-repo.gpg | sudo gpg --dearmor -o /usr/share/keyrings/personal-apt.gpg</code></pre></div></div></div>
  <div class="card"><div class="step"><div class="num">2</div><div style="width:100%"><h3>Add the repository</h3><pre><code>echo "deb [signed-by=/usr/share/keyrings/personal-apt.gpg] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/personal-apt.list</code></pre></div></div></div>
  <div class="card"><div class="step"><div class="num">3</div><div style="width:100%"><h3>Install any app</h3><pre><code>sudo apt update
sudo apt install rustdesk              <span class="dim"># RustDesk</span>
sudo apt install mattermost-desktop    <span class="dim"># Mattermost</span></code></pre></div></div></div>

  ${APP_SECTIONS}

  <h2>No GPG key? (unsigned repo)</h2>
  <div class="warn">&#x26A0;&#xFE0F; Add <code>trusted=yes</code> to the source line:</div>
  <pre><code>echo "deb [trusted=yes] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/personal-apt.list</code></pre>

  <h2>Repository Details</h2>
  <div class="card">
    <table class="info">
      <tr><th>Repository URL</th><td><a href="${URL}">${URL}</a></td></tr>
      <tr><th>Distribution</th><td><code>stable</code></td></tr>
      <tr><th>Component</th><td><code>main</code></td></tr>
      <tr><th>Total apps</th><td>${APP_COUNT}</td></tr>
      <tr><th>Total versions</th><td>${TOTAL_VERSIONS}</td></tr>
      <tr><th>Source</th><td><a href="https://github.com/${SLUG}">github.com/${SLUG}</a></td></tr>
    </table>
  </div>

  <footer>
    <p>Unofficial community mirror. Not affiliated with any upstream project. &nbsp;&middot;&nbsp; <a href="https://github.com/${SLUG}">View source</a></p>
  </footer>
</div>
<script>
function filterTable(input,tbodyId){
  var q=input.value.toLowerCase();
  document.querySelectorAll('#'+tbodyId+' tr').forEach(function(r){
    r.style.display=r.textContent.toLowerCase().indexOf(q)!==-1?'':'none';
  });
}
</script>
</body>
</html>
HTMLEOF

echo "==> docs/index.html written (${APP_COUNT} apps, ${TOTAL_VERSIONS} versions)"