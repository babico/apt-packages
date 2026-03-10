#!/usr/bin/env bash
# generate-index.sh — Generate the HTML landing page for the APT repository.
# Reads tracked_versions.json to build the full version history table.
set -euo pipefail

LATEST="${1:?Usage: $0 <latest_version>}"
OWNER="${GITHUB_REPOSITORY_OWNER:-your-username}"
SLUG="${GITHUB_REPOSITORY:-your-username/rustdesk-repo}"
NAME="${SLUG##*/}"
URL="https://${OWNER}.github.io/${NAME}"
UPDATED=$(date -u '+%Y-%m-%d %H:%M UTC')
TRACKING="tracked_versions.json"

mkdir -p docs

# ── Build version history rows ────────────────────────────────────────────────
ROWS=""
TOTAL=0

if [ -f "$TRACKING" ]; then
  TOTAL=$(jq 'length' "$TRACKING")

  while IFS= read -r ROW; do
    V=$(echo "$ROW"        | jq -r '.version')
    REL=$(echo "$ROW"      | jq -r '.released_at // .added_at' | cut -c1-10)
    ARCHS_CSV=$(echo "$ROW"| jq -r '.archs | join(", ")')

    LATEST_BADGE=""
    ROW_CLASS=""
    [ "$V" = "$LATEST" ] && LATEST_BADGE=' <span class="badge-latest">latest</span>' && ROW_CLASS=' class="row-latest"'

    # Per-arch .deb download links
    DEB_LINKS=""
    while IFS= read -r ARCH; do
      case "$ARCH" in
        amd64) SFX="x86_64.deb"       ;;
        arm64) SFX="aarch64.deb"      ;;
        armhf) SFX="armv7-sciter.deb" ;;
        *)     SFX="${ARCH}.deb"       ;;
      esac
      PKG="rustdesk-${V}-${SFX}"
      DEB_LINKS="${DEB_LINKS}<a class=\"dl\" href=\"${URL}/pool/main/r/rustdesk/${PKG}\">${ARCH}</a>"
    done < <(echo "$ROW" | jq -r '.archs[]')

    ROWS="${ROWS}
      <tr${ROW_CLASS}>
        <td><code>${V}</code>${LATEST_BADGE}</td>
        <td>${REL}</td>
        <td><code>${ARCHS_CSV}</code></td>
        <td class=\"dl-cell\">${DEB_LINKS}</td>
        <td><a class=\"dl\" href=\"https://github.com/rustdesk/rustdesk/releases/tag/${V}\" target=\"_blank\" rel=\"noopener\">notes&nbsp;&#8599;</a></td>
      </tr>"
  done < <(jq -c '.[]' "$TRACKING")
fi

# ── Emit HTML ─────────────────────────────────────────────────────────────────
cat > docs/index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8"/>
  <meta name="viewport" content="width=device-width,initial-scale=1"/>
  <title>RustDesk APT Repository</title>
  <style>
    :root {
      --bg:#0d1117; --surface:#161b22; --border:#30363d;
      --text:#c9d1d9; --muted:#8b949e; --accent:#58a6ff;
      --green:#3fb950; --yellow:#d29922; --code-bg:#1c2128;
      --hi:#1c2c3c;
    }
    *{box-sizing:border-box;margin:0;padding:0}
    body{background:var(--bg);color:var(--text);
      font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Helvetica,Arial,sans-serif;
      line-height:1.6;padding:2rem 1rem}
    .wrap{max-width:960px;margin:0 auto}
    header{border-bottom:1px solid var(--border);padding-bottom:1.5rem;margin-bottom:2rem}
    h1{font-size:1.75rem;color:#e6edf3}
    h1 em{font-style:normal;color:var(--accent)}
    h2{font-size:1.05rem;color:#e6edf3;margin:2rem 0 .75rem}
    p{color:var(--muted);margin-bottom:.75rem}
    .card{background:var(--surface);border:1px solid var(--border);
      border-radius:8px;padding:1.2rem 1.4rem;margin-bottom:1rem}
    .card h3{font-size:.9rem;font-weight:600;color:#e6edf3;margin-bottom:.5rem}
    pre{background:var(--code-bg);border:1px solid var(--border);
      border-radius:6px;padding:.85rem 1rem;overflow-x:auto;
      font-size:.82rem;color:#e6edf3;margin:.35rem 0;
      white-space:pre;word-break:normal}
    pre code{display:block;min-width:0}
    code{font-family:"SFMono-Regular",Consolas,"Liberation Mono",Menlo,monospace}
    .dim{color:var(--muted)}
    /* Step cards */
    .step{display:flex;gap:.75rem;align-items:flex-start}
    .num{min-width:1.6rem;height:1.6rem;border-radius:50%;background:var(--accent);
      color:#fff;display:flex;align-items:center;justify-content:center;
      font-size:.78rem;font-weight:700;flex-shrink:0;margin-top:.15rem}
    /* arch sub-labels inside step 2 */
    .arch-label{margin:.55rem 0 .3rem;font-size:.82rem;color:var(--muted)}
    /* Badges */
    .badge-latest{display:inline-block;padding:.12em .5em;border-radius:2em;
      font-size:.7rem;font-weight:700;margin-left:.35rem;vertical-align:middle;
      background:#238636;color:#fff}
    /* Version table */
    .tbl-wrap{overflow-x:auto;margin-top:.5rem}
    table{width:100%;border-collapse:collapse;font-size:.84rem}
    th{padding:.5rem .7rem;text-align:left;border-bottom:2px solid var(--border);
      color:var(--muted);font-weight:600;white-space:nowrap}
    td{padding:.45rem .7rem;border-bottom:1px solid var(--border);vertical-align:middle}
    tr.row-latest td{background:var(--hi)}
    tr:hover td{background:#1a2030}
    .dl-cell{white-space:nowrap}
    .dl{display:inline-block;padding:.12em .45em;border-radius:4px;
      margin:.1em .1em;background:#21262d;border:1px solid var(--border);
      color:var(--accent);font-size:.78rem;text-decoration:none;white-space:nowrap}
    .dl:hover{background:#30363d}
    /* Search */
    .search{width:100%;padding:.5rem .75rem;margin-bottom:.6rem;
      background:var(--code-bg);border:1px solid var(--border);
      border-radius:6px;color:var(--text);font-size:.875rem}
    .search::placeholder{color:var(--muted)}
    /* Warning box */
    .warn{background:#2d1f00;border:1px solid #6e4c00;border-radius:6px;
      padding:.7rem 1rem;margin:.6rem 0;font-size:.875rem;color:#e3b341}
    /* Info table */
    .info td,.info th{padding:.4rem .7rem;border-bottom:1px solid var(--border);font-size:.875rem}
    .info th{color:var(--muted);font-weight:600}
    footer{margin-top:3rem;padding-top:1.5rem;border-top:1px solid var(--border);
      font-size:.8rem;color:var(--muted)}
    a{color:var(--accent);text-decoration:none}
    a:hover{text-decoration:underline}
  </style>
</head>
<body>
<div class="wrap">

  <header>
    <h1>&#x1F5A5; <em>RustDesk</em> APT Repository</h1>
    <p style="margin-top:.4rem">
      Unofficial mirror &mdash; <strong>${TOTAL} version(s)</strong> available.
      Synced from <a href="https://github.com/rustdesk/rustdesk/releases">github.com/rustdesk/rustdesk</a>.
      Updated: <strong>${UPDATED}</strong> &mdash; Latest: <code>${LATEST}</code>
    </p>
  </header>

  <!-- ── Quick install ──────────────────────────────────── -->
  <h2>Quick Install &mdash; ${LATEST}</h2>
  <div class="card">
    <h3>amd64 (one-liner)</h3>
    <pre><code>curl -fsSL ${URL}/rustdesk-apt.gpg | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/rustdesk.list
sudo apt update &amp;&amp; sudo apt install rustdesk</code></pre>
  </div>

  <!-- ── Step by step ───────────────────────────────────── -->
  <h2>Step-by-step Setup</h2>

  <div class="card">
    <div class="step">
      <div class="num">1</div>
      <div style="width:100%">
        <h3>Import the signing key</h3>
        <pre><code>curl -fsSL ${URL}/rustdesk-apt.gpg | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step">
      <div class="num">2</div>
      <div style="width:100%">
        <h3>Add the repository &mdash; choose your architecture</h3>
        <p class="arch-label">amd64 (x86-64):</p>
        <pre><code>echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>
        <p class="arch-label">arm64 (AArch64 / Raspberry Pi 64-bit):</p>
        <pre><code>echo "deb [arch=arm64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>
        <p class="arch-label">armhf (ARMv7 32-bit):</p>
        <pre><code>echo "deb [arch=armhf signed-by=/usr/share/keyrings/rustdesk.gpg] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step">
      <div class="num">3</div>
      <div style="width:100%">
        <h3>Install</h3>
        <pre><code>sudo apt update &amp;&amp; sudo apt install rustdesk</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step">
      <div class="num">4</div>
      <div style="width:100%">
        <h3>Stay updated</h3>
        <pre><code>sudo apt upgrade rustdesk</code></pre>
        <p style="margin-top:.4rem">All future releases are picked up automatically by <code>apt upgrade</code>.</p>
      </div>
    </div>
  </div>

  <!-- ── Pin / downgrade ────────────────────────────────── -->
  <h2>Install a specific version</h2>
  <div class="card">
    <h3>Install exact version</h3>
    <pre><code><span class="dim"># Any version from the table below</span>
sudo apt install rustdesk=1.4.5</code></pre>
    <h3 style="margin-top:1rem">Hold (prevent auto-upgrade)</h3>
    <pre><code>sudo apt-mark hold rustdesk
sudo apt-mark unhold rustdesk   <span class="dim"># re-enable</span></code></pre>
    <h3 style="margin-top:1rem">Downgrade</h3>
    <pre><code>sudo apt install rustdesk=1.4.4</code></pre>
  </div>

  <!-- ── Version table ──────────────────────────────────── -->
  <h2>All available versions (${TOTAL})</h2>
  <p>Every version below is in the APT index. Install any with <code>apt install rustdesk=VERSION</code> or download the <code>.deb</code> directly.</p>

  <input class="search" id="search" type="search" placeholder="Filter versions&hellip;" oninput="filter(this.value)" />

  <div class="tbl-wrap">
    <table>
      <thead>
        <tr><th>Version</th><th>Released</th><th>Architectures</th><th>Download .deb</th><th>Changelog</th></tr>
      </thead>
      <tbody id="tbody">
        ${ROWS}
      </tbody>
    </table>
  </div>

  <!-- ── Unsigned fallback ──────────────────────────────── -->
  <h2>No GPG key? (unsigned repo)</h2>
  <div class="warn">&#x26A0;&#xFE0F; If the repository is not signed, add <code>trusted=yes</code> to the source line:</div>
  <pre><code>echo "deb [arch=amd64 trusted=yes] ${URL} stable main" | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>

  <!-- ── Details ────────────────────────────────────────── -->
  <h2>Repository Details</h2>
  <div class="card">
    <table class="info">
      <tr><th>Repository URL</th>    <td><a href="${URL}">${URL}</a></td></tr>
      <tr><th>Distribution</th>      <td><code>stable</code></td></tr>
      <tr><th>Component</th>         <td><code>main</code></td></tr>
      <tr><th>Latest version</th>    <td><code>${LATEST}</code></td></tr>
      <tr><th>Total versions</th>    <td>${TOTAL}</td></tr>
      <tr><th>Mirror source</th>     <td><a href="https://github.com/${SLUG}">github.com/${SLUG}</a></td></tr>
      <tr><th>Upstream releases</th> <td><a href="https://github.com/rustdesk/rustdesk/releases">github.com/rustdesk/rustdesk/releases</a></td></tr>
    </table>
  </div>

  <footer>
    <p>Unofficial community mirror. RustDesk is by <a href="https://rustdesk.com">RustDesk Ltd</a> (AGPL-3.0). Not affiliated with the RustDesk project. &nbsp;&middot;&nbsp; <a href="https://github.com/${SLUG}">View source</a></p>
  </footer>
</div>
<script>
function filter(q){
  q=q.toLowerCase();
  document.querySelectorAll('#tbody tr').forEach(r=>{
    r.style.display=r.textContent.toLowerCase().includes(q)?'':'none';
  });
}
</script>
</body>
</html>
HTMLEOF

echo "==> docs/index.html written (${TOTAL} versions)"