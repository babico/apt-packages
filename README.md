# Personal Packages Repository

Multi-platform package repository. Mirrors packages from upstream releases for easy installation on Linux (APT/Homebrew), Windows (Scoop), and macOS (Homebrew).

## Included Apps

| App | Upstream | APT | Scoop | Homebrew |
|-----|----------|-----|-------|----------|
| [RustDesk](https://rustdesk.com) | [rustdesk/rustdesk](https://github.com/rustdesk/rustdesk) | amd64, arm64, armhf | amd64 | arm64, x64, amd64 |
| [Mattermost Desktop](https://mattermost.com) | [mattermost/desktop](https://github.com/mattermost/desktop) | amd64, arm64 | amd64 | arm64, x64, amd64 |
| [Tixati](https://tixati.com) | download.tixati.com | amd64, i386 | amd64 | amd64 (Linux only) |
| [GitHub CLI](https://cli.github.com) | [cli/cli](https://github.com/cli/cli) | amd64, i386, arm64, armhf | amd64 | arm64, x64, amd64 |
| [Apidog](https://apidog.com) | apidog.com (zip download) | amd64, arm64, rpm | amd64, x86 | arm64, x64, amd64, arm64 |

## How it works

```
apps.json (app definitions)
        ↓
  GitHub Actions (every 6 hours)
  ┌──────────────────────────────────────────────────────────┐
  │ update-apt.yml      → .deb download → APT index → Pages │
  │ update-scoop.yml    → detect new versions → update JSON │
  │ update-homebrew.yml → detect new versions → update RB   │
  │ build-apidog-rpm.yml→ tar.gz → rpmbuild → RPM pool      │
  └──────────────────────────────────────────────────────────┘
        ↓
  https://babico.github.io/packages
```

**Auto-bootstrap:** on the very first push (when a tracking file is empty), the workflow automatically downloads **all** historical releases for that app. No manual trigger needed.

---

## APT (Linux)

### Quick setup

```bash
curl -fsSL https://babico.github.io/packages/apt-repo.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/personal-apt.gpg

echo "deb [signed-by=/usr/share/keyrings/personal-apt.gpg] \
  https://babico.github.io/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/personal-apt.list

sudo apt update
```

### Install apps

```bash
sudo apt install rustdesk
sudo apt install mattermost-desktop
sudo apt install tixati
sudo apt install gh
sudo apt install apidog
```

### Install a specific version

```bash
sudo apt install rustdesk=1.4.5
sudo apt install gh=2.95.0
```

### Hold / downgrade

```bash
sudo apt-mark hold rustdesk            # prevent upgrades
sudo apt install rustdesk=1.4.4        # downgrade
sudo apt-mark unhold rustdesk          # re-enable upgrades
```

---

## Scoop (Windows)

```bash
scoop bucket add personal https://github.com/babico/packages
scoop install rustdesk mattermost-desktop tixati gh apidog
```

---

## Homebrew (macOS / Linux)

```bash
brew tap babico/packages
brew install rustdesk mattermost-desktop gh apidog  # macOS + Linux
brew install tixati                                # Linux only (no macOS build)
```

---

## Adding a new app

### GitHub-hosted apps (RustDesk, Mattermost, gh style)

Edit `apps.json` and add:

```json
{
  "name": "my-app",
  "display_name": "My App",
  "description": "Description",
  "homepage": "https://example.com",
  "source": "github",
  "github_repo": "owner/repo",
  "pool_letter": "m",
  "architectures": {
    "amd64": "amd64.deb",
    "arm64": "arm64.deb"
  },
  "download_url": "https://github.com/owner/repo/releases/download/v${VERSION}/my-app_${VERSION}_${SUFFIX}",
  "deb_pattern": "my-app_${VERSION}_${SUFFIX}",
  "version_prefix": "v"
}
```

### Directory listing apps (Tixati style)

For apps that publish to a plain HTTP directory listing with no GitHub API:

```json
{
  "name": "my-app",
  "display_name": "My App",
  "description": "Description",
  "homepage": "https://example.com",
  "source": "http_listing",
  "listing_url": "https://downloads.example.com/",
  "version_regex": "my-app-([0-9.]+)-amd64\\.deb",
  "pool_letter": "m",
  "architectures": {
    "amd64": "amd64.deb"
  },
  "download_url": "https://downloads.example.com/my-app-${VERSION}-amd64.deb",
  "deb_pattern": "my-app-${VERSION}-amd64.deb",
  "version_prefix": ""
}
```

The `version_regex` must have **one capture group** that extracts the version string from filenames in the directory listing.

### Zip-download apps (Apidog style)

For apps that wrap packages in a zip file:

```json
{
  "name": "my-app",
  "display_name": "My App",
  "description": "Description",
  "homepage": "https://example.com",
  "source": "zip_download",
  "pool_letter": "m",
  "architectures": {
    "amd64": "my-app-linux-amd64-latest.zip",
    "arm64": "my-app-linux-arm64-latest.zip"
  },
  "download_url": "https://example.com/download/${SUFFIX}",
  "extract_regex": "my-app_([0-9.]+)_"
}
```

The workflow downloads the zip, extracts the `.deb` inside, and uses `extract_regex` to detect version changes.

### Then add Scoop and Homebrew manifests

1. **Scoop:** Add `scoop-bucket/bucket/my-app.json` (see existing manifests as templates)
2. **Homebrew:** Add `homebrew-tap/Formula/my-app.rb` (see existing formulas as templates)

Push to `main` — the workflows will auto-detect the new app and download releases.

---

## Setting up your own fork

### 1. Create the repo

```bash
gh repo create packages --public --clone
```

### 2. Enable GitHub Pages

Settings → Pages → Source: **GitHub Actions**

### 3. (Optional) GPG signing

```bash
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: Personal APT Mirror
Name-Email: noreply@example.com
Expire-Date: 0
EOF

gpg --armor --export-secret-keys "Personal APT Mirror" > private.key
gpg --armor --export "Personal APT Mirror" > docs/apt-repo.gpg
git add docs/apt-repo.gpg && git commit -m "add gpg pubkey"
```

Add these secrets in Settings → Secrets → Actions:

| Secret | Value |
|--------|-------|
| `GPG_PRIVATE_KEY` | Content of `private.key` |
| `GPG_PASSPHRASE` | Key passphrase (blank if `%no-protection`) |

### 4. Push — bootstrap runs automatically

```bash
git push origin main
```

---

## Workflow inputs (manual dispatch)

### update-apt.yml

| Input | Default | Description |
|-------|---------|-------------|
| `force_rebuild` | false | Re-index pool without re-downloading |
| `backfill` | false | Force re-fetch all historical versions |
| `backfill_limit` | 0 | Limit backfill count per app (0 = all) |
| `specific_app` | — | Target a single app by name |
| `specific_version` | — | Add a single version (requires `specific_app`) |

### update-scoop.yml / update-homebrew.yml

| Input | Default | Description |
|-------|---------|-------------|
| `specific_app` | — | Target a single app by name |

### build-apidog-rpm.yml

No inputs — always builds from latest tarball.

---

## Storage

Each app version varies in size. GitHub Pages soft limit: **1 GB**.
Use `backfill_limit` to stay under if needed.

> Note: `.deb` files are in `docs/pool/` which is **gitignored** — they are downloaded fresh on each CI run and never committed to git history.

---

## Repository structure

```
apps.json                          # App definitions (name, URL patterns, archs)
tracked_versions/
  rustdesk.json                    # Per-app version tracking
  mattermost-desktop.json
  tixati.json
  gh.json
  apidog.json
scripts/
  download-debs.sh                 # Generic .deb downloader (reads apps.json)
  update-tracked-versions.sh       # Per-app version tracker
  build-repo.sh                    # APT index builder (all apps)
  generate-index.sh                # HTML landing page generator
docs/
  pool/main/{letter}/{app}/        # .deb files (gitignored)
  dists/stable/                    # APT metadata
  index.html                       # Landing page
  apt-repo.gpg                     # GPG public key
.github/workflows/
  update-apt.yml                   # APT repo: detect new versions, download, deploy
  update-scoop.yml                 # Scoop: detect new versions, update manifests
  update-homebrew.yml              # Homebrew: detect new versions, update formulas
  build-apidog-rpm.yml             # RPM: build Apidog RPM from tarball
scoop-bucket/
  bucket/                          # Scoop manifests (Windows)
    rustdesk.json
    mattermost-desktop.json
    tixati.json
    gh.json
    apidog.json
homebrew-tap/
  Formula/                         # Homebrew formulas (macOS + Linux)
    rustdesk.rb
    mattermost-desktop.rb
    gh.rb
    apidog.rb
    tixati.rb                      # Linux only (no macOS build)
```

---

MIT license. Upstream projects retain their own licenses.