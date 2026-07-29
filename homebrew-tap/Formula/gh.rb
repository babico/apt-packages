class Gh < Formula
  desc "GitHub's official command line tool"
  homepage "https://cli.github.com"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_mac_arm64.zip"
      sha256 "placeholder"
    end
    on_intel do
      url "https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_mac_amd64.zip"
      sha256 "placeholder"
    end

    version "2.96.0"

    def install
      system "unzip", "-q", pkgfiles.first
      bin.install "gh"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_linux_arm64.deb"
      sha256 "placeholder"
    end
    on_intel do
      url "https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_linux_amd64.deb"
      sha256 "placeholder"
    end

    version "2.96.0"

    def install
      system "dpkg", "-x", pkgfiles.first, "."
      bin.install "usr/bin/gh"
    end
  end
end