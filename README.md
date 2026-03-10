# RustDesk APT Repository (GitHub Pages)

An automatically-updated APT (`apt`) repository for [RustDesk](https://github.com/rustdesk/rustdesk), hosted free on **GitHub Pages** and rebuilt every 6 hours via GitHub Actions. Supports **all versions** — users can install the latest or pin to any historical release.

## How It Works

```plaintext
rustdesk/rustdesk releases → GitHub Actions → APT repo index (all versions) → GitHub Pages
```

1. A scheduled workflow polls the upstream RustDesk GitHub releases API every 6 hours.
2. New versions are downloaded (`.deb` for `amd64`, `arm64`, `armhf`) into a persistent pool.
3. The **entire pool** is re-indexed into a proper `dists/stable/` APT index every run — all versions are always available to `apt`.
4. `tracked_versions.json` tracks every mirrored version with metadata.
5. The landing page lists every version with direct `.deb` download links and a search filter.

---

## 🚀 Using This Repository (end users)

### Install the latest version

```bash
# 1. Import the signing key
curl -fsSL https://YOUR_USERNAME.github.io/rustdesk-apt/rustdesk-apt.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg

# 2. Add the source (replace arch= with: amd64 / arm64 / armhf)
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] \
  https://YOUR_USERNAME.github.io/rustdesk-apt stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list

# 3. Install
sudo apt update && sudo apt install rustdesk
```

### Install a specific (older) version

```bash
sudo apt install rustdesk=1.4.5
```

### Hold / pin a version (prevent auto-upgrades)

```bash
sudo apt-mark hold rustdesk      # pin current version
sudo apt-mark unhold rustdesk    # release the pin
```

### Downgrade

```bash
sudo apt install rustdesk=1.4.4
```

### Without GPG signing

```bash
echo "deb [arch=amd64 trusted=yes] https://YOUR_USERNAME.github.io/rustdesk-apt stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list
sudo apt update && sudo apt install rustdesk
```

---

## 🔧 Setting Up Your Own Fork

### 1. Fork / create this repository

```bash
gh repo create rustdesk-apt --public
```

### 2. Enable GitHub Pages

Settings → Pages → Source: **GitHub Actions**

### 3. (Optional) Add a GPG signing key

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
```

Add repo secrets (**Settings → Secrets → Actions**):

| Secret            | Value                                  |
| ----------------- | -------------------------------------- |
| `GPG_PRIVATE_KEY` | Contents of `private.key`              |
| `GPG_PASSPHRASE`  | Passphrase (empty if `%no-protection`) |

### 4. Backfill all historical versions (first-time setup)

Actions → **Update RustDesk APT Repository** → Run workflow:

- Set `backfill` = `true`
- Set `backfill_limit` = `0` (all) or e.g. `10` (last 10)

> ⚠️ Backfilling all versions downloads ~150–200 MB of `.deb` files.
> GitHub Pages has a **1 GB soft limit** — use `backfill_limit` to stay well under it.

### 5. Add a single missing version manually

Actions → Run workflow → `specific_version` = `1.3.9`

---

## Workflow Inputs

| Input | Default | Description |
| ----- | ------- | ----------- |
| `force_rebuild` | `false` | Re-index pool even if no new versions |
| `backfill` | `false` | Fetch all historical releases |
| `backfill_limit` | `0` | Max releases to backfill (0 = all) |
| `specific_version` | `` | Add one specific version by tag |

---

## Repository Structure

```plaintext
.
├── .github/workflows/update-repo.yml   # Main CI/CD workflow
├── scripts/
│   ├── download-debs.sh                # Downloads .deb for a given version
│   ├── build-repo.sh                   # Indexes full pool → Packages/Release files
│   ├── update-tracked-versions.sh      # Maintains tracked_versions.json
│   └── generate-index.sh              # Generates HTML landing page
├── tracked_versions.json               # All mirrored versions + metadata
└── docs/                               # GitHub Pages root (auto-generated)
    ├── index.html
    ├── rustdesk-apt.gpg
    ├── pool/main/r/rustdesk/           # All .deb files (all versions)
    │   ├── rustdesk-1.4.6-x86_64.deb
    │   ├── rustdesk-1.4.5-x86_64.deb
    │   └── ...
    └── dists/stable/main/
        ├── binary-amd64/Packages(.gz)
        ├── binary-arm64/Packages(.gz)
        └── binary-armhf/Packages(.gz)
```

---

## Storage considerations

Each RustDesk release is roughly 20–30 MB per architecture × 3 archs ≈ **~70 MB per version**.
GitHub Pages has a 1 GB soft limit, so you can comfortably host ~14 versions before pruning older ones.
Use `backfill_limit` to control how many historical versions to keep.

---

## License

Mirror tooling: MIT. RustDesk itself: [AGPL-3.0](https://github.com/rustdesk/rustdesk/blob/master/LICENCE).
