class Rustdesk < Formula
  desc "Open-source remote desktop software"
  homepage "https://rustdesk.com"
  license "AGPL-3.0"

  on_macos do
    on_arm do
      url "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-aarch64.dmg"
      sha256 "f7935597b247d42c8f2a2ed71176a9f5868018cd9e1a33b8096418a668c8caf0"
    end
    on_intel do
      url "https://github.com/rustdesk/rustdesk/releases/download/1.4.9/rustdesk-1.4.9-x86_64.dmg"
      sha256 "fa1129a0635019f9c5841937942cc2b08be028a192f47c009edde7e53812904e"
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
    sha256 "7244ba47c40e804172044bfbe659467c54ce46554c98e78c8c0406f1d612fda3"
    version "1.4.9"

    def install
      system "dpkg", "-x", pkgfiles.first, "."
      bin.install "usr/bin/rustdesk" if File.exist?("usr/bin/rustdesk")
      if File.exist?("opt")
        prefix.install "opt"
        Dir.glob("opt/**/rustdesk").each do |f|
          bin.install f
        end
      end
    end
  end
end