class MattermostDesktop < Formula
  desc "Mattermost desktop application for team messaging"
  homepage "https://mattermost.com"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/mattermost/desktop/releases/download/v6.3.0/mattermost-desktop-6.3.0-mac-arm64.dmg"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
    on_intel do
      url "https://github.com/mattermost/desktop/releases/download/v6.3.0/mattermost-desktop-6.3.0-mac-x64.dmg"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end

    version "6.3.0"

    def install
      system "hdiutil", "attach", "-nobrowse", "-mountpoint", "#{var}/mount", pkgfiles.first
      mv "#{var}/mount/Mattermost.app", libexec
      system "hdiutil", "detach", "#{var}/mount"
      appdir.install libexec/"Mattermost.app"
    end
  end

  on_linux do
    url "https://github.com/mattermost/desktop/releases/download/v6.3.0/mattermost-desktop-6.3.0-linux-x86_64.rpm"
    sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    version "6.3.0"

    def install
      system "rpm2cpio", pkgfiles.first, "|", "cpio", "-idmv"
      bin.install "usr/bin/mattermost-desktop" if File.exist?("usr/bin/mattermost-desktop")
    end
  end
end
