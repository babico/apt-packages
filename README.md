# RustDesk APT Repository (GitHub Pages)

An automatically-updated APT (`apt`) repository for [RustDesk](https://github.com/rustdesk/rustdesk), hosted free on **GitHub Pages** and rebuilt every 6 hours via GitHub Actions.

## How It Works

```plaintext
rustdesk/rustdesk releases → GitHub Actions → APT repo index → GitHub Pages
```

1. A scheduled workflow polls the upstream RustDesk GitHub releases API every 6 hours.
2. When a new version is detected, it downloads the `.deb` packages for `amd64`, `arm64`, and `armhf`.
3. It rebuilds a proper `dists/stable/` APT index (Packages, Release, InRelease, Release.gpg).
4. The result is deployed to GitHub Pages — a fully functional APT repo.

---

## 🚀 Using This Repository (for end users)

### Signed install (recommended)

```bash
# 1. Import the signing key
curl -fsSL https://YOUR_USERNAME.github.io/rustdesk-apt/rustdesk-apt.gpg \
  | sudo gpg --dearmor -o /usr/share/keyrings/rustdesk.gpg

# 2. Add the source (replace arch= with your architecture: amd64 / arm64 / armhf)
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/rustdesk.gpg] \
  https://YOUR_USERNAME.github.io/rustdesk-apt stable main" \
  | sudo tee /etc/apt/sources.list.d/rustdesk.list

# 3. Install
sudo apt update && sudo apt install rustdesk
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
cd rustdesk-apt
# copy all files from this template
```

### 2. Enable GitHub Pages

In your repo → **Settings → Pages**:

- Source: **GitHub Actions**

### 3. (Optional but recommended) Add a GPG signing key

Generate a dedicated key:

```bash
gpg --batch --gen-key <<EOF
%no-protection
Key-Type: RSA
Key-Length: 4096
Subkey-Type: RSA
Subkey-Length: 4096
Name-Real: RustDesk APT Mirror
Name-Email: noreply@example.com
Expire-Date: 0
EOF

# Export the private key
gpg --armor --export-secret-keys "RustDesk APT Mirror" > private.key

# Export the public key (commit this to the repo as rustdesk-apt.gpg)
gpg --armor --export "RustDesk APT Mirror" > docs/rustdesk-apt.gpg
```

Add these secrets to your repository (**Settings → Secrets and variables → Actions**):

| Secret name       | Value                                        |
| ----------------- | -------------------------------------------- |
| `GPG_PRIVATE_KEY` | Contents of `private.key` (armored)          |
| `GPG_PASSPHRASE`  | Passphrase (leave empty if `%no-protection`) |

### 4. Trigger the first run

```bash
gh workflow run update-repo.yml --field force_rebuild=true
```

Or push any commit to trigger the workflow manually via the Actions tab.

---

## Repository Structure

```tree
.
├── .github/
│   └── workflows/
│       └── update-repo.yml       # Main CI/CD workflow
├── scripts/
│   ├── download-debs.sh          # Downloads .deb files from upstream
│   ├── build-repo.sh             # Builds APT index (Packages, Release, etc.)
│   └── generate-index.sh         # Generates HTML landing page
├── docs/                         # GitHub Pages root (auto-generated)
│   ├── index.html                # Landing page
│   ├── rustdesk-apt.gpg          # Public GPG key
│   └── dists/
│       └── stable/
│           ├── Release
│           ├── InRelease
│           ├── Release.gpg
│           └── main/
│               ├── binary-amd64/
│               │   ├── Packages
│               │   └── Packages.gz
│               ├── binary-arm64/
│               └── binary-armhf/
└── tracked_version.txt           # Currently mirrored version
```

---

## Workflow Triggers

| Trigger | When |
| ------- | ---- |
| Scheduled | Every 6 hours (`0 */6 * * *`) |
| Manual dispatch | Via GitHub Actions UI or `gh workflow run` |
| `force_rebuild` input | Rebuilds even if version hasn't changed |

---

## Supported Architectures

| Architecture | APT label | RustDesk build |
| - | - | - |
| x86-64 | `amd64` | `rustdesk-X.Y.Z-x86_64.deb` |
| AArch64 | `arm64` | `rustdesk-X.Y.Z-aarch64.deb` |
| ARMv7 | `armhf` | `rustdesk-X.Y.Z-armv7-sciter.deb` |

---

## License

This mirror tooling is MIT licensed. RustDesk itself is [AGPL-3.0](https://github.com/rustdesk/rustdesk/blob/master/LICENCE).
