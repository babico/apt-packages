#!/usr/bin/env bash
# build-index.sh — Generate compact HTML landing page.
set -uo pipefail
shopt -s nullglob

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

APP_COUNT=0; TOTAL_VERSIONS=0
APP_CARDS=""; APP_NAV=""; VERSION_ROWS=""

for dir in "$BUILD_DIR"/*/; do
  config="$dir/config.yml"
  [ -f "$config" ] || continue
  APP_COUNT=$((APP_COUNT + 1))

  app_name=$(yget "$config" name)
  display=$(yget "$config" display)
  desc=$(yget "$config" description)
  homepage=$(yget "$config" homepage)
  pool_letter=$(yget "$config" pool_letter)
  git_repo=$(yget "$config" repo)
  prefix=$(yget "$config" version_prefix)
  changelog_url=$(yget "$config" changelog_url)

  TRACKING="$TRACK_DIR/${app_name}.json"
  TOTAL=0; LATEST=""; ROWS=""

  if [ -f "$TRACKING" ]; then
    TOTAL=$(jq -r 'length // 0' "$TRACKING")
    TOTAL_VERSIONS=$((TOTAL_VERSIONS + TOTAL))
    LATEST=$(jq -r 'if length == 0 then "" else max_by([(.released_at // .added_at // ""), ((.version // "") | split(".") | map(tonumber? // 0))]) | .version // "" end' "$TRACKING")

    while IFS= read -r ROW; do
      V=$(echo "$ROW"|jq -r '.version')
      REL=$(echo "$ROW"|jq -r '.released_at//.added_at'|cut -c1-10)
      ARCHS=$(echo "$ROW"|jq -r '.archs|join(",")')
      latest_class=""; [ "$V" = "$LATEST" ] && latest_class=' class="row-latest"'

      DEB_LINKS=""
      while IFS= read -r ARCH; do
        for bf in "$dir"deb-*.yml; do
          [ -f "$bf" ] || continue
          [ "$(yget "$bf" arch)" = "$ARCH" ] || continue
          pkg=$(find "docs/pool/main/${pool_letter}/${app_name}/" -name "*_${ARCH}.deb" -print 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "")
          [ -n "$pkg" ] && DEB_LINKS="${DEB_LINKS}<a class=\"dl\" href=\"${URL}/pool/main/${pool_letter}/${app_name}/${pkg}\">${ARCH}</a>"
          break
        done
      done < <(echo "$ROW"|jq -r '.archs[]' 2>/dev/null || true)

      tag="${prefix}${V}"
      if [ -n "$changelog_url" ]; then
        C_LINK="<a class=\"dl\" href=\"${changelog_url}\">log</a>"
      elif [ -n "$git_repo" ]; then
        C_LINK="<a class=\"dl\" href=\"https://github.com/${git_repo}/releases/tag/${tag}\">log</a>"
      else
        C_LINK="<a class=\"dl\" href=\"${homepage}\">site</a>"
      fi

      ROWS="${ROWS}
        <tr${latest_class}>
          <td><code>${V}</code>$([ "$V" = "$LATEST" ] && echo ' <span class="badge-latest">latest</span>')</td>
          <td>${REL}</td>
          <td class=\"arch-cell\">${ARCHS}</td>
          <td>${DEB_LINKS}</td>
          <td>${C_LINK}</td>
        </tr>"
    done < <(jq -c '.[]' "$TRACKING")
  fi

  if [ -n "$changelog_url" ]; then
    link_line="<a href=\"${changelog_url}\">Changelog</a>"
  elif [ -n "$git_repo" ]; then
    link_line="<a href=\"https://github.com/${git_repo}/releases\">GitHub</a>"
  else
    link_line="<a href=\"${homepage}\">Website</a>"
  fi

  APP_NAV="${APP_NAV}<button class=\"nav-btn\" data-app=\"${app_name}\" onclick=\"toggleApp(this,'${app_name}')\">${display} <span class=\"dim\">${LATEST}</span></button>"

  APP_CARDS="${APP_CARDS}
  <div class=\"app-card\" id=\"card-${app_name}\" style=\"display:none\">
    <div class=\"card\">
      <h3>${display} <code style=\"font-size:.85rem\">${LATEST}</code></h3>
      <p class=\"muted\">${desc} &middot; ${link_line} &middot; <strong>${TOTAL} versions</strong></p>
      <pre class=\"compact\"><code>apt install ${app_name}     <span class=\"dim\"># Debian/Ubuntu</span>
scoop install ${app_name}          <span class=\"dim\"># Windows</span>
brew install ${app_name}           <span class=\"dim\"># macOS / Linux</span></code></pre>
      <input class=\"search\" type=\"search\" placeholder=\"Filter versions&hellip;\" oninput=\"filterTable(this,'tbody-${app_name}')\" />
      <div class=\"tbl-wrap\">
        <table>
          <thead><tr><th>Version</th><th>Released</th><th>Arch</th><th>.deb</th><th></th></tr></thead>
          <tbody id=\"tbody-${app_name}\">${ROWS}</tbody>
        </table>
      </div>
    </div>
  </div>"
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
    :root{--bg:#0d1117;--surface:#161b22;--border:#30363d;--text:#c9d1d9;--muted:#8b949e;--accent:#58a6ff;--green:#3fb950;--yellow:#d29922;--code-bg:#1c2128;--hi:#1c2c3c}
    *{box-sizing:border-box;margin:0;padding:0}
    body{background:var(--bg);color:var(--text);font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;line-height:1.5;padding:1.5rem 1rem}
    .wrap{max-width:900px;margin:0 auto}
    a{color:var(--accent);text-decoration:none}a:hover{text-decoration:underline}
    code{font-family:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace;font-size:.8rem}
    .muted{color:var(--muted)}
    .dim{color:var(--muted);font-size:.82rem}

    /* header */
    header{margin-bottom:1.5rem}
    h1{font-size:1.4rem;color:#e6edf3}
    header p{color:var(--muted);margin-top:.2rem;font-size:.85rem}

    /* nav */
    .nav-bar{display:flex;flex-wrap:wrap;gap:.35rem;margin:.8rem 0}
    .nav-btn{background:var(--surface);border:1px solid var(--border);color:var(--accent);padding:.35rem .7rem;border-radius:6px;cursor:pointer;font-size:.82rem;transition:all .15s}
    .nav-btn:hover,.nav-btn.active{background:#21262d;border-color:var(--accent)}
    .nav-btn .dim{font-size:.7rem;margin-left:.3rem}

    /* search */
    .global-search{width:100%;padding:.55rem .8rem;margin-bottom:1rem;background:var(--code-bg);border:1px solid var(--border);border-radius:8px;color:var(--text);font-size:.9rem;outline:none}
    .global-search:focus{border-color:var(--accent)}
    .global-search::placeholder{color:var(--muted)}

    /* tabs */
    .tabs{display:flex;gap:.25rem;margin-bottom:1rem}
    .tab{padding:.35rem .9rem;cursor:pointer;color:var(--muted);border:1px solid var(--border);background:var(--surface);border-radius:6px 6px 0 0;font-size:.8rem;border-bottom:none}
    .tab.active{color:var(--accent);background:#1c2c3c;border-color:var(--accent)}
    .tab-panel{display:none;border:1px solid var(--border);border-radius:0 6px 6px 6px;padding:1rem;background:var(--surface);margin-bottom:1rem}
    .tab-panel.active{display:block}

    /* cards */
    .card{background:var(--surface);border:1px solid var(--border);border-radius:8px;padding:1rem 1.2rem;margin-bottom:.8rem}
    .card h3{margin-bottom:.3rem;font-size:.95rem}
    .app-card{margin-bottom:.5rem}

    /* compact pre */
    pre.compact{background:var(--code-bg);border:1px solid var(--border);border-radius:4px;padding:.55rem .75rem;overflow-x:auto;font-size:.78rem;color:#e6edf3;margin:.4rem 0;line-height:1.5}

    /* expand btn */
    .expand-btn{background:none;border:1px solid var(--border);color:var(--accent);padding:.2rem .6rem;border-radius:4px;cursor:pointer;font-size:.75rem;margin-top:.3rem;transition:all .15s}
    .expand-btn:hover{background:var(--hi)}

    /* guide */
    .guide{display:none}
    .guide.open{display:block}

    /* tags */
    .tag{display:inline-block;padding:.1em .4em;border-radius:3px;font-size:.65rem;font-weight:700}
    .tag.apt{background:#1c3828;color:#3fb950}.tag.scoop{background:#1a2c3c;color:#58a6ff}.tag.brew{background:#2d1f00;color:#d29922}

    /* tables */
    .tbl-wrap{overflow-x:auto;margin-top:.4rem}
    table{width:100%;border-collapse:collapse;font-size:.8rem}
    th{padding:.4rem .6rem;text-align:left;border-bottom:2px solid var(--border);color:var(--muted);font-weight:600;font-size:.75rem}
    td{padding:.35rem .6rem;border-bottom:1px solid var(--border)}
    tr.row-latest td{background:var(--hi)}
    tr:hover td{background:#1a2030}
    .dl{display:inline-block;padding:.1em .35em;border-radius:3px;margin:.1em;background:#21262d;border:1px solid var(--border);color:var(--accent);font-size:.72rem;text-decoration:none}
    .dl:hover{background:#30363d}
    .badge-latest{display:inline-block;padding:.08em .4em;border-radius:2em;font-size:.6rem;font-weight:700;margin-left:.25rem;vertical-align:middle;background:#238636;color:#fff}

    .search{width:100%;padding:.4rem .6rem;margin-bottom:.5rem;background:var(--code-bg);border:1px solid var(--border);border-radius:4px;color:var(--text);font-size:.82rem;outline:none}
    .search:focus{border-color:var(--accent)}
    .search::placeholder{color:var(--muted)}

    .summary-table{margin-bottom:1.5rem}

    footer{margin-top:2rem;padding-top:1rem;border-top:1px solid var(--border);font-size:.75rem;color:var(--muted)}
    hr{border:none;border-top:1px solid var(--border);margin:1.5rem 0}
  </style>
</head>
<body>
<div class="wrap">
  <header>
    <h1>packages</h1>
    <p><strong>${APP_COUNT} apps</strong> &middot; <strong>${TOTAL_VERSIONS} versions</strong> &middot; APT / Scoop / Homebrew &middot; <span id="updated-label">Updated: ${UPDATED}</span>
    &nbsp;&middot;&nbsp; <a href="${GH_URL}">GitHub</a>
    &nbsp;&middot;&nbsp; <a href="#" onclick="toggleGuide()" id="guide-link">Guide</a></p>
  </header>

  <input class="global-search" type="search" id="global" placeholder="Search apps, versions, archs&hellip;" oninput="globalFilter()" />

  <!-- Guide (collapsed) -->
  <div class="guide card" id="guide">
    <h3>Setup Guide</h3>
    <div class="tabs">
      <button class="tab active" onclick="switchTab(event,'s-apt')">APT</button>
      <button class="tab" onclick="switchTab(event,'s-scoop')">Scoop</button>
      <button class="tab" onclick="switchTab(event,'s-brew')">Homebrew</button>
    </div>
    <div class="tab-panel active" id="s-apt">
      <pre class="compact"><code>curl -fsSL ${URL}/apt-repo.gpg | sudo gpg --dearmor -o /usr/share/keyrings/personal-apt.gpg
echo "deb [signed-by=/usr/share/keyrings/personal-apt.gpg] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/personal-apt.list
sudo apt update
sudo apt install &lt;app&gt;</code></pre>
      <p class="muted" style="font-size:.75rem">No GPG? <code>echo "deb [trusted=yes] ..."</code></p>
    </div>
    <div class="tab-panel" id="s-scoop">
      <pre class="compact"><code>scoop bucket add personal ${GH_URL}
scoop install &lt;app&gt;</code></pre>
    </div>
    <div class="tab-panel" id="s-brew">
      <pre class="compact"><code>brew tap babico/packages
brew install &lt;app&gt;</code></pre>
    </div>
  </div>

  <!-- App selector buttons -->
  <div class="nav-bar">
    <button class="nav-btn active" onclick="showAll()">All apps</button>
    ${APP_NAV}
  </div>

  ${APP_CARDS}

  <footer>
    Unofficial mirror &middot; <a href="${GH_URL}">GitHub</a> &middot; <a href="https://apidog.canny.io/changelog">Apidog Changelog</a>
  </footer>
</div>
<script>
var activeApp=null;
function toggleApp(btn,id){
  if(activeApp===id){document.getElementById('card-'+id).style.display='none';activeApp=null;document.querySelectorAll('.nav-btn').forEach(function(b){b.classList.remove('active')});return}
  if(activeApp)document.getElementById('card-'+activeApp).style.display='none'
  document.getElementById('card-'+id).style.display='';activeApp=id
  document.querySelectorAll('.nav-btn').forEach(function(b){b.classList.remove('active')});btn.classList.add('active')
}
function showAll(){
  document.querySelectorAll('.app-card').forEach(function(c){c.style.display=''})
  document.querySelectorAll('.nav-btn').forEach(function(b){b.classList.remove('active');if(b.textContent.startsWith('All'))b.classList.add('active')})
  activeApp=null;document.getElementById('global').value=''
}
function globalFilter(){
  var q=document.getElementById('global').value.toLowerCase()
  if(!q){showAll();return}
  document.querySelectorAll('.app-card').forEach(function(c){
    c.style.display=c.textContent.toLowerCase().indexOf(q)!==-1?'':'none'
  })
  document.querySelectorAll('.nav-btn').forEach(function(b){b.classList.remove('active')})
  activeApp=null
}
function filterTable(input,tbodyId){
  var q=input.value.toLowerCase();
  document.querySelectorAll('#'+tbodyId+' tr').forEach(function(r){r.style.display=r.textContent.toLowerCase().indexOf(q)!==-1?'':'none'})
}
function switchTab(e,id){
  document.querySelectorAll('.tab-panel,.tab').forEach(function(el){el.classList.remove('active')})
  document.getElementById(id).classList.add('active');e.target.classList.add('active')
}
function toggleGuide(){
  var g=document.getElementById('guide');g.classList.toggle('open')
  document.getElementById('guide-link').textContent=g.classList.contains('open')?'Hide guide':'Guide'
}
</script>
</body>
</html>
HTMLEOF

echo "==> docs/index.html written (${APP_COUNT} apps, ${TOTAL_VERSIONS} versions)"