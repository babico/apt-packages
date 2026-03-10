#!/usr/bin/env bash
# generate-index.sh — Build the HTML landing page with full version history.
set -euo pipefail

LATEST_VERSION="${1:?Usage: $0 <latest_version>}"
REPO_OWNER="${GITHUB_REPOSITORY_OWNER:-your-github-username}"
REPO_SLUG="${GITHUB_REPOSITORY:-your-github-username/rustdesk-apt}"
REPO_NAME="${REPO_SLUG##*/}"
PAGES_URL="https://${REPO_OWNER}.github.io/${REPO_NAME}"
UPDATED=$(date -u '+%Y-%m-%d %H:%M UTC')
TRACKING_FILE="tracked_versions.json"

mkdir -p docs

# ── Build the version history table rows from tracked_versions.json ──────────
VERSION_ROWS=""
TOTAL_VERSIONS=0

if [ -f "$TRACKING_FILE" ]; then
  TOTAL_VERSIONS=$(jq 'length' "$TRACKING_FILE")

  while IFS= read -r ROW; do
    VERSION=$(echo "$ROW" | jq -r '.version')
    RELEASED=$(echo "$ROW" | jq -r '.released_at // .added_at' | cut -c1-10)
    ARCHS=$(echo "$ROW"    | jq -r '.archs | join(", ")')

    IS_LATEST=""
    BADGE=""
    if [ "$VERSION" = "$LATEST_VERSION" ]; then
      IS_LATEST=' class="latest-row"'
      BADGE=' <span class="badge">latest</span>'
    fi

    # Build direct .deb download links for each architecture
    DEB_LINKS=""
    while IFS= read -r ARCH; do
      case "$ARCH" in
        amd64) SUFFIX="x86_64.deb"       ;;
        arm64) SUFFIX="aarch64.deb"      ;;
        armhf) SUFFIX="armv7-sciter.deb" ;;
        *)     SUFFIX="${ARCH}.deb"      ;;
      esac
      PKG="rustdesk-${VERSION}-${SUFFIX}"
      POOL_URL="${PAGES_URL}/pool/main/r/rustdesk/${PKG}"
      DEB_LINKS="${DEB_LINKS}<a class=\"deb-link\" href=\"${POOL_URL}\">${ARCH}</a> "
    done < <(echo "$ROW" | jq -r '.archs[]')

    VERSION_ROWS="${VERSION_ROWS}
      <tr${IS_LATEST}>
        <td><code>${VERSION}</code>${BADGE}</td>
        <td>${RELEASED}</td>
        <td><code>${ARCHS}</code></td>
        <td>${DEB_LINKS}</td>
        <td>
          <a class=\"deb-link\" href=\"https://github.com/rustdesk/rustdesk/releases/tag/${VERSION}\"
             target=\"_blank\" rel=\"noopener\">changelog ↗</a>
        </td>
      </tr>"
  done < <(jq -c '.[]' "$TRACKING_FILE")
fi

# ── Emit the full HTML page ───────────────────────────────────────────────────
cat > docs/index.html <<HTMLEOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>RustDesk APT Repository</title>
  <style>
    :root {
      --bg: #0d1117; --surface: #161b22; --border: #30363d;
      --text: #c9d1d9; --muted: #8b949e; --accent: #58a6ff;
      --green: #3fb950; --yellow: #d29922; --code-bg: #1c2128;
      --highlight: #1c2c3c;
    }
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      background: var(--bg); color: var(--text);
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Helvetica, Arial, sans-serif;
      line-height: 1.6; padding: 2rem 1rem;
    }
    .container { max-width: 920px; margin: 0 auto; }
    header { border-bottom: 1px solid var(--border); padding-bottom: 1.5rem; margin-bottom: 2rem; }
    h1 { font-size: 1.8rem; color: #e6edf3; }
    h1 span { color: var(--accent); }
    .badge {
      display: inline-block; padding: .15em .55em; border-radius: 2em;
      font-size: .72rem; font-weight: 600; margin-left: .4rem;
      vertical-align: middle; background: #238636; color: #fff;
    }
    .badge-old {
      background: #30363d; color: var(--muted);
    }
    h2 { font-size: 1.1rem; color: #e6edf3; margin: 2rem 0 .8rem; }
    p { color: var(--muted); margin-bottom: .75rem; }
    .card {
      background: var(--surface); border: 1px solid var(--border);
      border-radius: 8px; padding: 1.2rem 1.4rem; margin-bottom: 1.1rem;
    }
    .card-title { font-weight: 600; color: #e6edf3; margin-bottom: .55rem; }
    pre {
      background: var(--code-bg); border: 1px solid var(--border);
      border-radius: 6px; padding: .9rem 1.1rem; overflow-x: auto;
      font-size: .85rem; color: #e6edf3; margin: .4rem 0;
    }
    code { font-family: "SFMono-Regular", Consolas, "Liberation Mono", Menlo, monospace; }
    .comment { color: var(--muted); }
    .step { display: flex; gap: .75rem; align-items: flex-start; margin-bottom: .4rem; }
    .step-num {
      min-width: 1.6rem; height: 1.6rem; border-radius: 50%;
      background: var(--accent); color: #fff;
      display: flex; align-items: center; justify-content: center;
      font-size: .78rem; font-weight: 700; flex-shrink: 0; margin-top: .15rem;
    }
    /* Version history table */
    .version-table-wrap { overflow-x: auto; }
    .version-table {
      width: 100%; border-collapse: collapse; font-size: .85rem;
    }
    .version-table th {
      padding: .55rem .75rem; text-align: left;
      border-bottom: 2px solid var(--border);
      color: var(--muted); font-weight: 600; white-space: nowrap;
    }
    .version-table td {
      padding: .5rem .75rem;
      border-bottom: 1px solid var(--border);
      vertical-align: middle;
    }
    .version-table tr.latest-row td { background: var(--highlight); }
    .version-table tr:hover td { background: #1a2030; }
    .deb-link {
      display: inline-block;
      padding: .15em .5em; border-radius: 4px; margin: .1em .15em;
      background: #21262d; border: 1px solid var(--border);
      color: var(--accent); font-size: .78rem; text-decoration: none;
      white-space: nowrap;
    }
    .deb-link:hover { background: #30363d; }
    /* Pin to a specific version */
    .pin-box {
      background: #0d1b2a; border: 1px solid #1f4068;
      border-radius: 6px; padding: .75rem 1rem; margin: .75rem 0;
    }
    .warn-box {
      background: #2d1f00; border: 1px solid #6e4c00;
      border-radius: 6px; padding: .75rem 1rem; margin: .75rem 0;
      font-size: .875rem; color: #e3b341;
    }
    .info-table { width: 100%; border-collapse: collapse; font-size: .875rem; }
    .info-table th, .info-table td {
      padding: .45rem .75rem; text-align: left;
      border-bottom: 1px solid var(--border);
    }
    .info-table th { color: var(--muted); font-weight: 600; }
    .ok { color: var(--green); }
    footer {
      margin-top: 3rem; padding-top: 1.5rem;
      border-top: 1px solid var(--border);
      font-size: .8rem; color: var(--muted);
    }
    a { color: var(--accent); text-decoration: none; }
    a:hover { text-decoration: underline; }
    .search-bar {
      width: 100%; padding: .5rem .75rem; margin-bottom: .75rem;
      background: var(--code-bg); border: 1px solid var(--border);
      border-radius: 6px; color: var(--text); font-size: .875rem;
    }
    .search-bar::placeholder { color: var(--muted); }
  </style>
</head>
<body>
<div class="container">

  <header>
    <h1>🖥️ <span>RustDesk</span> APT Repository</h1>
    <p style="margin-top:.5rem">
      Unofficial APT mirror tracking <strong>${TOTAL_VERSIONS} version(s)</strong> —
      auto-synced from
      <a href="https://github.com/rustdesk/rustdesk/releases">github.com/rustdesk/rustdesk</a>.
      Last updated: <strong>${UPDATED}</strong>.
      Latest: <code>${LATEST_VERSION}</code>.
    </p>
  </header>

  <!-- ── Quick Install ──────────────────────────────────── -->
  <h2>Quick Install (latest — ${LATEST_VERSION})</h2>
  <div class="card">
    <div class="card-title">One-liner</div>
    <pre><code>curl -fsSL ${PAGES_URL}/rustdesk-apt.gpg | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list
sudo apt update && sudo apt install rustdesk</code></pre>
  </div>

  <!-- ── Step-by-step ───────────────────────────────────── -->
  <h2>Step-by-step Setup</h2>

  <div class="card">
    <div class="step"><div class="step-num">1</div>
      <div>
        <div class="card-title">Import signing key</div>
        <pre><code>curl -fsSL ${PAGES_URL}/rustdesk-apt.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step"><div class="step-num">2</div>
      <div>
        <div class="card-title">Add the repository</div>
        <pre><code><span class="comment"># amd64 (x86-64)</span>
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list

<span class="comment"># arm64 (AArch64 / Raspberry Pi 64-bit)</span>
echo "deb [arch=arm64 signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list

<span class="comment"># armhf (ARMv7 32-bit)</span>
echo "deb [arch=armhf signed-by=/usr/share/keyrings/rustdesk.gpg] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step"><div class="step-num">3</div>
      <div>
        <div class="card-title">Install</div>
        <pre><code>sudo apt update && sudo apt install rustdesk</code></pre>
      </div>
    </div>
  </div>

  <div class="card">
    <div class="step"><div class="step-num">4</div>
      <div>
        <div class="card-title">Stay updated</div>
        <pre><code>sudo apt upgrade rustdesk</code></pre>
        <p style="margin-top:.4rem">APT will always upgrade to the latest mirrored release.</p>
      </div>
    </div>
  </div>

  <!-- ── Pin to a specific version ─────────────────────── -->
  <h2>Install or pin a specific version</h2>
  <div class="card">
    <div class="card-title">Install a specific version</div>
    <pre><code><span class="comment"># Replace 1.4.5 with any version from the table below</span>
sudo apt install rustdesk=1.4.5</code></pre>
    <div class="card-title" style="margin-top:1rem">Hold a version (prevent upgrades)</div>
    <pre><code>sudo apt-mark hold rustdesk</code></pre>
    <div class="card-title" style="margin-top:1rem">Unhold (re-enable upgrades)</div>
    <pre><code>sudo apt-mark unhold rustdesk</code></pre>
    <div class="card-title" style="margin-top:1rem">Downgrade to a previous version</div>
    <pre><code>sudo apt install rustdesk=1.4.4</code></pre>
  </div>

  <!-- ── Version history ────────────────────────────────── -->
  <h2>All available versions (${TOTAL_VERSIONS})</h2>
  <p>All versions listed below are present in the APT index and installable via <code>apt install rustdesk=VERSION</code>.
  Direct <code>.deb</code> download links are also provided for each architecture.</p>

  <input class="search-bar" id="versionSearch" type="search"
         placeholder="Filter versions…" oninput="filterVersions(this.value)" />

  <div class="version-table-wrap">
    <table class="version-table" id="versionTable">
      <thead>
        <tr>
          <th>Version</th>
          <th>Released</th>
          <th>Architectures</th>
          <th>Download .deb</th>
          <th>Changelog</th>
        </tr>
      </thead>
      <tbody id="versionTbody">
        ${VERSION_ROWS}
      </tbody>
    </table>
  </div>

  <!-- ── Unsigned repo fallback ─────────────────────────── -->
  <h2>No GPG key? (unsigned)</h2>
  <div class="warn-box">
    ⚠️ If this repo is not GPG-signed, add <code>trusted=yes</code>:
  </div>
  <pre><code>echo "deb [arch=amd64 trusted=yes] ${PAGES_URL} stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list</code></pre>

  <!-- ── Repo details ───────────────────────────────────── -->
  <h2>Repository Details</h2>
  <div class="card">
    <table class="info-table">
      <tr><th>Property</th><th>Value</th></tr>
      <tr><td>Repository URL</td>   <td><a href="${PAGES_URL}">${PAGES_URL}</a></td></tr>
      <tr><td>Distribution</td>     <td><code>stable</code></td></tr>
      <tr><td>Component</td>        <td><code>main</code></td></tr>
      <tr><td>Latest version</td>   <td><code>${LATEST_VERSION}</code></td></tr>
      <tr><td>Total versions</td>   <td>${TOTAL_VERSIONS}</td></tr>
      <tr><td>Source</td>           <td><a href="https://github.com/${REPO_SLUG}">github.com/${REPO_SLUG}</a></td></tr>
      <tr><td>Upstream releases</td><td><a href="https://github.com/rustdesk/rustdesk/releases">github.com/rustdesk/rustdesk/releases</a></td></tr>
    </table>
  </div>

  <footer>
    <p>
      Unofficial community mirror. RustDesk is by
      <a href="https://rustdesk.com">RustDesk Ltd</a> — AGPL-3.0.
      Not affiliated with the RustDesk project.
      &nbsp;·&nbsp;
      <a href="https://github.com/${REPO_SLUG}">View source</a>
    </p>
  </footer>
</div>

<script>
function filterVersions(query) {
  const q = query.toLowerCase();
  document.querySelectorAll('#versionTbody tr').forEach(row => {
    row.style.display = row.textContent.toLowerCase().includes(q) ? '' : 'none';
  });
}
</script>
</body>
</html>
HTMLEOF

echo "==> Landing page written to docs/index.html (${TOTAL_VERSIONS} versions listed)"