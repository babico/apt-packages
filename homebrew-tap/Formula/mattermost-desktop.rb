class MattermostDesktop < Formula
  desc "Mattermost desktop application for team messaging"
  homepage "https://mattermost.com"
  license "MIT"

  on_macos do
    on_arm do
      url "https://github.com/mattermost/desktop/releases/download/v6.2.2/mattermost-desktop-6.2.2-mac-arm64.dmg"
      sha256 "0bf3ed5b8bc6b994974b09e136157015656121f40c1b60c2a36bcb3c16309a17"
    end
    on_intel do
      url "https://github.com/mattermost/desktop/releases/download/v6.2.2/mattermost-desktop-6.2.2-mac-x64.dmg"
      sha256 "ce0ff37adf57c1d99eb83a5e3e7e2c0e951996f631be99e94c23919c8f9a2695"
    end

    version "6.2.2"

    def install
      system "hdiutil", "attach", "-nobrowse", "-mountpoint", "#{var}/mount", pkgfiles.first
      mv "#{var}/mount/Mattermost.app", libexec
      system "hdiutil", "detach", "#{var}/mount"
      appdir.install libexec/"Mattermost.app"
    end
  end

  on_linux do
    url "https://github.com/mattermost/desktop/releases/download/v6.2.2/mattermost-desktop-6.2.2-linux-x86_64.rpm"
    sha256 "de9984854e956ebfd5c14d6ad705c6184a1252e864ea433f3fa9def440d2133b"
    version "6.2.2"

    depends_on "rpm2cpio" => :build

    def install
      system "rpm2cpio", pkgfiles.first | "cpio", "-idmv"
      bin.install "usr/bin/mattermost-desktop" if File.exist?("usr/bin/mattermost-desktop")
    end
  end
end