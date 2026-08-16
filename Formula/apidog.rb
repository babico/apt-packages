class Apidog < Formula
  desc "API design, development, and documentation platform"
  homepage "https://apidog.com"
  license "Freeware"

  on_macos do
    on_arm do
      url "https://file-assets.apidog.com/download/Apidog-macOS-arm64-latest.zip"
      sha256 "5d2fdcf722c032f1e294e9032b1472e22d77a77f86fddc46e1e5837f66866cf3"
    end
    on_intel do
      url "https://file-assets.apidog.com/download/Apidog-macOS-latest.zip"
      sha256 "4fe7f0a02f0af6c929fb97b5b67bdb2ad034eeffb0445a289b0bf162c689d58c"
    end

    version "2.8.43"

    def install
      system "unzip", "-q", pkgfiles.first
      dmg = Dir["*.dmg"].first
      system "hdiutil", "attach", "-nobrowse", "-mountpoint", "#{var}/mount", dmg
      mv "#{var}/mount/Apidog.app", libexec
      system "hdiutil", "detach", "#{var}/mount"
      appdir.install libexec/"Apidog.app"
    end
  end

  on_linux do
    on_arm do
      url "https://file-assets.apidog.com/download/Apidog-linux-arm64-deb-latest.zip"
      sha256 "0b8076d3f3008c8500977ac2f70e9acd114a706eea0b4cca0512b3d0510b57ba"
    end
    on_intel do
      url "https://file-assets.apidog.com/download/Apidog-linux-deb-latest.zip"
      sha256 "ca9c6a71ad31038c9a909f2515982adda8d73245c45e1979bbd87f25a618a183"
    end

    version "2.8.43"

    def install
      system "unzip", "-q", pkgfiles.first
      deb = Dir["*.deb"].first
      system "dpkg", "-x", deb, "."
      bin.install "usr/bin/apidog" if File.exist?("usr/bin/apidog")
    end
  end
end
