class Rustdesk < Formula
  desc "Open-source remote desktop software"
  homepage "https://rustdesk.com"
  license "AGPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-aarch64.dmg"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end
    on_intel do
      url "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.dmg"
      sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    end

    version "1.4.9"

    def install
      system "hdiutil", "attach", "-nobrowse", "-mountpoint", "#{var}/mount", pkgfiles.first
      mv "#{var}/mount/RustDesk.app", libexec
      system "hdiutil", "detach", "#{var}/mount"
      appdir.install libexec/"RustDesk.app"
    end
  end

  on_linux do
    url "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.deb"
    sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"
    version "1.4.9"

    def install
      system "dpkg", "-x", pkgfiles.first, "."
      bin.install "usr/bin/rustdesk" if File.exist?("usr/bin/rustdesk")
    end
  end
end
