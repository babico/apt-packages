# packages

Multi-platform package repository with GitHub Actions automation.

| App | APT (Linux) | Scoop (Windows) | Homebrew (macOS/Linux) |
|-----|-------------|-----------------|----------------------|
| [RustDesk](https://rustdesk.com) | amd64, arm64, armhf | amd64 | arm64, x86, amd64 |
| [Mattermost Desktop](https://mattermost.com) | amd64, arm64 | amd64 | arm64, x86, amd64 |
| [Tixati](https://tixati.com) | amd64, i386 | amd64 | amd64 (Linux only) |
| [GitHub CLI](https://cli.github.com) | amd64, i386, arm64, armhf | amd64 | arm64, x86, amd64 |
| [Apidog](https://apidog.com) | amd64, arm64 | amd64, x86 | arm64, x86, amd64, arm64 |

---

## APT (Linux)

### Setup

```bash
curl -fsSL https://babico.github.io/packages/apt-repo.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/personal-apt.gpg

echo "deb [signed-by=/usr/share/keyrings/personal-apt.gpg] \
  https://babico.github.io/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/personal-apt.list

sudo apt update
```

### Install

```bash
sudo apt install rustdesk mattermost-desktop tixati gh apidog
```

### Install specific version

```bash
sudo apt install rustdesk=1.4.5
sudo apt install gh=2.95.0
```

### Hold / downgrade

```bash
sudo apt-mark hold rustdesk
sudo apt install rustdesk=1.4.4
sudo apt-mark unhold rustdesk
```

### Unsigned fallback

```bash
echo "deb [trusted=yes] https://babico.github.io/packages stable main" \
  | sudo tee /etc/apt/sources.list.d/personal-apt.list
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
brew install rustdesk mattermost-desktop gh apidog    # macOS + Linux
brew install tixati                                   # Linux only
```

---

## Repo structure

```
docs/                           # GitHub Pages (APT repo)
  dists/stable/                 # APT index (Packages, Release, signed)
  pool/main/{letter}/{app}/     # .deb / .rpm files (gitignored)

.github/build/{product}/        # Build definitions
  config.yml                    # Product metadata
  deb-{arch}.yml                # DEB build targets
  dmg-{arch}.yml                # DMG build targets
  rpm.yml                       # RPM build target
  scoop.json.tmpl               # Scoop manifest template
  brew.rb.tmpl                  # Homebrew formula template
  rpm.spec.tmpl                 # RPM spec template

scripts/
  build-all.sh                  # Orchestrator (detect → download → index → deploy)
  build-apt.sh                  # APT index generator
  build-index.sh                # HTML landing page
  yaml-get.py                   # YAML reader

bucket/                         # Scoop manifests (generated)
Formula/                        # Homebrew formulas (generated)
tracked/                        # Version tracking per product

.github/workflows/update.yml    # Single CI workflow (every 6h)
```

## How it works

```
.github/build/{product}/
        ↓
   build-all.sh
   ┌───────────────────────────────────────────┐
   │ 1. detect version (github API / scrape)   │
   │ 2. download .deb → docs/pool/             │
   │ 3. build scoop.json from template         │
   │ 4. build brew.rb from template            │
   │ 5. build apt index (dpkg-scanpackages)    │
   │ 6. generate landing page                  │
   │ 7. commit → push → deploy to Pages        │
   └───────────────────────────────────────────┘
```

## Adding a new app

Create a folder under `.github/build/` with:

```
.github/build/my-app/
  config.yml          # name, display, homepage, source type
  deb-amd64.yml       # download URL, suffix, pool_name
  scoop.json.tmpl     # ${VERSION}, ${SHA256} placeholders
  brew.rb.tmpl        # ${VERSION}, ${MAC_ARM_URL}, ${LINUX_AMD64_SHA256}, etc.
```

**config.yml — GitHub-hosted app:**

```yaml
name: my-app
display: My App
description: Description
homepage: https://example.com
source: github
repo: owner/repo
pool_letter: m
version_prefix: v
```

**config.yml — directory listing source (Tixati-style):**

```yaml
name: my-app
source: http_listing
listing_url: https://downloads.example.com/
version_match: "my-app-([0-9.]+)-amd64\\.deb"
```

**config.yml — zip download source (Apidog-style):**

```yaml
name: my-app
source: zip_download
extract_regex: "my-app_([0-9.]+)_"
```

**deb-amd64.yml:**

```yaml
format: deb
arch: amd64
suffix: amd64.deb
download_url: "https://example.com/downloads/${VERSION}/my-app_${VERSION}_amd64.deb"
pool_name: "my-app_${VERSION}_amd64.deb"
```

**Template placeholders:**

| Template | Placeholders |
|----------|-------------|
| `scoop.json.tmpl` | `${VERSION}`, `${SHA256}` |
| `brew.rb.tmpl` | `${VERSION}`, `${MAC_ARM_URL}`, `${MAC_ARM_SHA256}`, `${MAC_X86_URL}`, `${MAC_X86_SHA256}`, `${LINUX_ARM_URL}`, `${LINUX_ARM_SHA256}`, `${LINUX_AMD64_URL}`, `${LINUX_AMD64_SHA256}` |
| `rpm.spec.tmpl` | `__VERSION__`, `__CHANGELOG__` |

---

MIT license. Upstream projects retain their own licenses.