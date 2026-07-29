#!/usr/bin/env bash
# build-index.sh — Generate HTML landing page from .github/build/*/ configs.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/../.github/build"
TRACK_DIR="$SCRIPT_DIR/../tracked"
PY="$SCRIPT_DIR/yaml-get.py"

yget() { python3 "$PY" "$@"; }

OWNER="${GITHUB_REPOSITORY_OWNER:-babico}"
SLUG="${GITHUB_REPOSITORY:-babico/packages}"
NAME="${SLUG##*/}"
URL="https://${OWNER}.github.io/${NAME}"
GH_URL="https://github.com/${SLUG}"
UPDATED=$(date -u '+%Y-%m-%d %H:%M UTC')

mkdir -p docs

APP_COUNT=0
TOTAL_VERSIONS=0
APP_SECTIONS=""
APP_NAV=""
VERSION_TABLE_ROWS=""

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
  changelog_url=$(yget "$config" changelog_url)
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
      if [ -n "$changelog_url" ]; then
        CHANGELOG_LINK="<a class=\"dl\" href=\"${changelog_url}\" target=\"_blank\" rel=\"noopener\">changelog</a>"
      elif [ -n "$git_repo" ]; then
        CHANGELOG_LINK="<a class=\"dl\" href=\"https://github.com/${git_repo}/releases/tag/${tag}\" target=\"_blank\" rel=\"noopener\">notes</a>"
      else
        CHANGELOG_LINK="<a class=\"dl\" href=\"${homepage}\" target=\"_blank\" rel=\"noopener\">website</a>"
      fi

      ROWS="${ROWS}
        <tr${ROW_CLASS}>
          <td><code>${V}</code>${LATEST_BADGE}</td>
          <td>${REL}</td>
          <td class=\"arch-cell\"><code class=\"archs\">${ARCHS_CSV}</code></td>
          <td class=\"dl-cell\">${DEB_LINKS}</td>
          <td>${CHANGELOG_LINK}</td>
        </tr>"
    done < <(jq -c '.[]' "$TRACKING")
  fi

  APP_NAV="${APP_NAV}<a href=\"#${app_name}\" class=\"nav-app\">${display}</a> "

  # Version summary row
  VERSION_TABLE_ROWS="${VERSION_TABLE_ROWS}
        <tr>
          <td><a href=\"#${app_name}\"><strong>${display}</strong></a></td>
          <td><code>${LATEST:-—}</code></td>
          <td><span class=\"tag apt\">apt</span> <span class=\"tag scoop\">scoop</span> <span class=\"tag brew\">brew</span></td>
          <td>${TOTAL} version(s)</td>
        </tr>"

  if [ -n "$changelog_url" ]; then
    RELEASES_LINK="<a href=\"${changelog_url}\">Changelog</a>"
  elif [ -n "$git_repo" ]; then
    RELEASES_LINK="<a href=\"https://github.com/${git_repo}/releases\">GitHub releases</a>"
  else
    RELEASES_LINK="<a href=\"${homepage}\">${homepage}</a>"
  fi

  APP_SECTIONS="${APP_SECTIONS}
  <section id=\"${app_name}\">
    <h3>${display}</h3>
    <p>${description} &mdash; ${RELEASES_LINK}
      &nbsp;|&nbsp; <strong>${TOTAL} version(s)</strong>
      $([ -n "$LATEST" ] && echo "&nbsp;|&nbsp; Latest: <code>${LATEST}</code>")</p>

    <h4>Install</h4>
    <div class=\"card\">
      <pre><code>sudo apt install ${app_name}           <span class=\"dim\"># APT (Linux)</span>
scoop install ${app_name}                 <span class=\"dim\"># Scoop (Windows)</span>
brew install ${app_name}                  <span class=\"dim\"># Homebrew (macOS/Linux)</span></code></pre>
    </div>

    <input class=\"search\" type=\"search\" placeholder=\"Filter ${display} versions&hellip;\" oninput=\"filterTable(this,'tbody-${app_name}')\" />
    <div class=\"tbl-wrap\">
      <table>
        <thead><tr><th>Version</th><th>Released</th><th>Arch</th><th>.deb</th><th>Info</th></tr></thead>
        <tbody id=\"tbody-${app_name}\">${ROWS}</tbody>
      </table>
    </div>
  </section>"
done

# ── HTML ──────────────────────────────────────────────────────────────

cat > docs/index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>Personal Packages — APT / Scoop / Homebrew</title>
  <style>
    :root{--bg:#0d1117;--surface:#161b22;--border:#30363d;--text:#c9d1d9;--muted:#8b949e;--accent:#58a6ff;--green:#3fb950;--code-bg:#1c2128;--hi:#1c2c3c}
    *{box-sizing:border-box;margin:0;padding:0}
    body{background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;line-height:1.6;padding:2rem 1rem}
    .wrap{max-width:960px;margin:0 auto}
    header{border-bottom:1px solid var(--border);padding-bottom:1.5rem;margin-bottom:2rem}
    h1{font-size:1.75rem;color:#e6edf3}
    h2{font-size:1.25rem;color:#e6edf3;margin:2rem 0 .75rem}
    h3{font-size:1.05rem;color:#e6edf3;margin:2.5rem 0 .5rem}
    h4{font-size:.9rem;color:var(--muted);margin:1rem 0 .3rem}
    p{color:var(--muted);margin-bottom:.75rem;font-size:.9rem}
    a{color:var(--accent);text-decoration:none}
    a:hover{text-decoration:underline}
    code{font-family:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace;font-size:.82rem}
    /* ── global search ─────────────────────── */
    .global-search{width:100%;padding:.65rem .85rem;margin-bottom:1.5rem;background:var(--code-bg);border:1px solid var(--border);border-radius:8px;color:var(--text);font-size:.95rem;outline:none}
    .global-search:focus{border-color:var(--accent)}
    .global-search::placeholder{color:var(--muted)}
    /* ── tabs ──────────────────────────────── */
    .tabs{display:flex;gap:0;margin-bottom:1.5rem;border-bottom:1px solid var(--border)}
    .tab{padding:.5rem 1.2rem;cursor:pointer;color:var(--muted);border:none;background:none;font-size:.88rem;border-bottom:2px solid transparent;transition:all .15s}
    .tab:hover{color:var(--text)}
    .tab.active{color:var(--accent);border-bottom-color:var(--accent)}
    .tab-content{display:none}
    .tab-content.active{display:block}
    /* ── version table ─────────────────────── */
    .ver-table{width:100%;border-collapse:collapse;font-size:.85rem;margin-bottom:1.5rem}
    .ver-table th{padding:.55rem .8rem;text-align:left;border-bottom:2px solid var(--border);color:var(--muted);font-weight:600;font-size:.78rem}
    .ver-table td{padding:.5rem .8rem;border-bottom:1px solid var(--border)}
    .ver-table tr:hover td{background:var(--hi)}
    /* ── card ──────────────────────────────── */
    .card{background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:1.2rem 1.4rem;margin-bottom:1rem}
    pre{background:var(--code-bg);border:1px solid var(--border);border-radius:6px;padding:.85rem 1rem;overflow-x:auto;font-size:.82rem;color:#e6edf3;margin:.35rem 0;white-space:pre;line-height:1.65}
    /* ── tags ──────────────────────────────── */
    .tag{display:inline-block;padding:.1em .45em;border-radius:3px;font-size:.7rem;font-weight:700}
    .tag.apt{background:#1c3828;color:#3fb950}
    .tag.scoop{background:#1a2c3c;color:#58a6ff}
    .tag.brew{background:#2d1f00;color:#d29922}
    /* ── nav ───────────────────────────────── */
    .nav-apps{display:flex;flex-wrap:wrap;gap:.3rem;margin:.75rem 0}
    .nav-app{display:inline-block;padding:.3em .7em;border-radius:6px;background:var(--surface);border:1px solid var(--border);color:var(--accent);font-size:.82rem;text-decoration:none}
    .nav-app:hover{background:#21262d}
    .dim{color:var(--muted)}
    .badge-latest{display:inline-block;padding:.12em .5em;border-radius:2em;font-size:.65rem;font-weight:700;margin-left:.35rem;vertical-align:middle;background:#238636;color:#fff}
    .tbl-wrap{overflow-x:auto;margin-top:.5rem}
    table{width:100%;border-collapse:collapse;font-size:.84rem}
    th{padding:.5rem .7rem;text-align:left;border-bottom:2px solid var(--border);color:var(--muted);font-weight:600;white-space:nowrap}
    td{padding:.45rem .7rem;border-bottom:1px solid var(--border);vertical-align:middle}
    tr.row-latest td{background:var(--hi)}
    tr:hover td{background:#1a2030}
    .dl-cell{white-space:nowrap}
    .dl{display:inline-block;padding:.12em .45em;border-radius:4px;margin:.1em;background:#21262d;border:1px solid var(--border);color:var(--accent);font-size:.78rem;text-decoration:none;white-space:nowrap}
    .dl:hover{background:#30363d}
    .search{width:100%;padding:.5rem .75rem;margin-bottom:.6rem;background:var(--code-bg);border:1px solid var(--border);border-radius:6px;color:var(--text);font-size:.875rem}
    .search::placeholder{color:var(--muted)}
    .search:focus{border-color:var(--accent);outline:none}
    .warn{background:#2d1f00;border:1px solid #6e4c00;border-radius:6px;padding:.7rem 1rem;margin:.6rem 0;font-size:.875rem;color:#e3b341}
    .info td,.info th{padding:.4rem .7rem;border-bottom:1px solid var(--border);font-size:.85rem}
    .info th{color:var(--muted);font-weight:600}
    footer{margin-top:3rem;padding-top:1.5rem;border-top:1px solid var(--border);font-size:.8rem;color:var(--muted)}
    hr{border:none;border-top:1px solid var(--border);margin:2.5rem 0}
  </style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>Personal Packages</h1>
    <p style="margin-top:.3rem"><strong>${APP_COUNT} apps</strong> &middot; <strong>${TOTAL_VERSIONS} versions</strong> &middot; APT / Scoop / Homebrew &middot; Updated: <strong>${UPDATED}</strong></p>
    <div class="nav-apps">${APP_NAV}</div>
  </header>

  <!-- ── Global search ──────────────────────── -->
  <input class="global-search" type="search" id="globalsearch" placeholder="Search all apps and versions&hellip; (e.g. rustdesk, 1.4.9, amd64)" oninput="globalFilter()" />

  <!-- ── Platform tabs ──────────────────────── -->
  <div class="tabs">
    <button class="tab active" onclick="switchTab('apt')">APT (Linux)</button>
    <button class="tab" onclick="switchTab('scoop')">Scoop (Windows)</button>
    <button class="tab" onclick="switchTab('brew')">Homebrew (macOS/Linux)</button>
  </div>

  <div id="apt" class="tab-content active">
    <div class="card">
      <h3 style="margin-top:0">Add repository</h3>
      <pre><code>curl -fsSL ${URL}/apt-repo.gpg | sudo gpg --dearmor -o /usr/share/keyrings/personal-apt.gpg
echo "deb [signed-by=/usr/share/keyrings/personal-apt.gpg] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/personal-apt.list
sudo apt update</code></pre>
    </div>
    <div class="card">
      <h3 style="margin-top:0">Install</h3>
      <pre><code>sudo apt install rustdesk
sudo apt install mattermost-desktop
sudo apt install tixati
sudo apt install gh
sudo apt install apidog</code></pre>
    </div>
    <div class="warn">No GPG key? <code>echo "deb [trusted=yes] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/personal-apt.list</code></div>
  </div>

  <div id="scoop" class="tab-content">
    <div class="card">
      <h3 style="margin-top:0">Add bucket</h3>
      <pre><code>scoop bucket add personal ${GH_URL}</code></pre>
    </div>
    <div class="card">
      <h3 style="margin-top:0">Install</h3>
      <pre><code>scoop install rustdesk
scoop install mattermost-desktop
scoop install tixati
scoop install gh
scoop install apidog</code></pre>
    </div>
  </div>

  <div id="brew" class="tab-content">
    <div class="card">
      <h3 style="margin-top:0">Add tap</h3>
      <pre><code>brew tap babico/packages</code></pre>
    </div>
    <div class="card">
      <h3 style="margin-top:0">Install</h3>
      <pre><code>brew install rustdesk mattermost-desktop gh apidog   <span class="dim"># macOS &amp; Linux</span>
brew install tixati                                  <span class="dim"># Linux only</span></code></pre>
    </div>
  </div>

  <!-- ── Version summary ────────────────────── -->
  <h2>All Apps</h2>
  <div class="tbl-wrap">
    <table class="ver-table">
      <thead><tr><th>App</th><th>Latest</th><th>Platforms</th><th>Versions</th></tr></thead>
      <tbody>${VERSION_TABLE_ROWS}</tbody>
    </table>
  </div>

  <hr>

  <!-- ── Per-app details ───────────────────── -->
  ${APP_SECTIONS}

  <hr>

  <footer>
    <p>Unofficial community mirror. Not affiliated with upstream projects. &nbsp;&middot;&nbsp; <a href="${GH_URL}">View source</a></p>
  </footer>
</div>

<script>
function switchTab(id){
  document.querySelectorAll('.tab-content').forEach(function(e){e.classList.remove('active')});
  document.querySelectorAll('.tab').forEach(function(e){e.classList.remove('active')});
  document.getElementById(id).classList.add('active');
  event.target.classList.add('active');
}

function filterTable(input,tbodyId){
  var q=input.value.toLowerCase();
  document.querySelectorAll('#'+tbodyId+' tr').forEach(function(r){
    r.style.display=r.textContent.toLowerCase().indexOf(q)!==-1?'':'none';
  });
}

function globalFilter(){
  var q=document.getElementById('globalsearch').value.toLowerCase();
  if(!q){
    document.querySelectorAll('section').forEach(function(s){s.style.display=''});
    document.querySelectorAll('hr').forEach(function(h){h.style.display=''}); 
    document.querySelectorAll('h3').forEach(function(h){h.style.display=''});
    return;
  }
  document.querySelectorAll('section').forEach(function(s){
    var match=s.textContent.toLowerCase().indexOf(q)!==-1;
    s.style.display=match?'':'none';
    var prev=s.previousElementSibling;
    if(prev&&prev.tagName==='HR') prev.style.display=match?'':'none';
    var h=s.querySelector('h3');
  });
}
</script>
</body>
</html>
HTMLEOF

echo "==> docs/index.html written (${APP_COUNT} apps, ${TOTAL_VERSIONS} versions)"