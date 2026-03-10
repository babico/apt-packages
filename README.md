# RustDesk APT Repository

Unofficial APT mirror for [RustDesk](https://github.com/rustdesk/rustdesk), hosted on GitHub Pages. All stable releases are available — install the latest or pin any historical version.

## How it works

```
GitHub API (all releases)
        ↓
  GitHub Actions
  ┌──────────────────────────────────────┐
  │ 1. Detect new / missing versions     │
  │ 2. Download .deb → docs/pool/        │
  │ 3. dpkg-scanpackages → Packages.gz   │
  │ 4. Generate Release + InRelease      │
  │ 5. Deploy to GitHub Pages            │
  └──────────────────────────────────────┘
        ↓
  https://YOUR_USERNAME.github.io/rustdesk-repo
```

**Auto-bootstrap:** on the very first push (when `tracked_versions.json` is empty), the workflow automatically downloads **all** historical RustDesk releases. No manual trigger needed.

---

## Using this repository

### Install latest

```bash
curl -fsSL https://YOUR_USERNAME.github.io/rustdesk-repo/rustdesk-apt.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg

echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] \
  https://YOUR_USERNAME.github.io/rustdesk-repo stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list

sudo apt update && sudo apt install rustdesk
```

### Install a specific version

```bash
sudo apt install rustdesk=1.4.5
```

### Hold / downgrade

```bash
sudo apt-mark hold rustdesk          # prevent upgrades
sudo apt install rustdesk=1.4.4      # downgrade
sudo apt-mark unhold rustdesk        # re-enable upgrades
```

---

## Setting up your own fork

### 1. Fork this repo

```bash
gh repo create rustdesk-repo --public --clone
```

### 2. Enable GitHub Pages

Settings → Pages → Source: **GitHub Actions**

### 3. (Optional) GPG signing

```bash
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Name-Real: RustDesk APT Mirror
Name-Email: noreply@example.com
Expire-Date: 0
EOF

gpg --armor --export-secret-keys "RustDesk APT Mirror" > private.key
gpg --armor --export "RustDesk APT Mirror" > docs/rustdesk-apt.gpg
git add docs/rustdesk-apt.gpg && git commit -m "add gpg pubkey"
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

The first push triggers the workflow which detects `tracked_versions.json` is empty and downloads **all** upstream releases.

---

## Workflow inputs (manual dispatch)

| Input | Default | Description |
|-------|---------|-------------|
| `force_rebuild` | false | Re-index without re-downloading |
| `backfill` | false | Force re-fetch all historical versions |
| `backfill_limit` | 0 | Limit backfill count (0 = all) |
| `specific_version` | — | Add a single version by tag |

---

## Storage

Each RustDesk version is ~70 MB across 3 architectures.
GitHub Pages soft limit: **1 GB** (~14 versions).
Use `backfill_limit` to stay under if needed.

> Note: `.deb` files are in `docs/pool/` which is **gitignored** — they are downloaded fresh on each CI run and never committed to git history.

---

## Supported architectures

| Architecture | APT label | Suffix |
|---|---|---|
| x86-64 | `amd64` | `x86_64.deb` |
| AArch64 | `arm64` | `aarch64.deb` |
| ARMv7 | `armhf` | `armv7-sciter.deb` |

---

MIT license. RustDesk is [AGPL-3.0](https://github.com/rustdesk/rustdesk/blob/master/LICENCE).