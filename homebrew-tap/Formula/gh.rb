class Gh < Formula
  desc "GitHub's official command line tool"
  homepage "https://cli.github.com"
  license "MIT"

  on_macos do
    on_arm do
      url ""
      sha256 ""
    end
    on_intel do
      url ""
      sha256 ""
    end

    version "2.96.0"

    def install
      system "unzip", "-q", pkgfiles.first
      bin.install "bin/gh"
    end
  end

  on_linux do
    on_arm do
      url "https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_linux_armv6.deb"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
    on_intel do
      url "https://github.com/cli/cli/releases/download/v2.96.0/gh_2.96.0_linux_amd64.deb"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end

    version "2.96.0"

    def install
      system "dpkg", "-x", pkgfiles.first, "."
      bin.install "usr/bin/gh"
    end
  end
end
