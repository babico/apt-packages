class Apidog < Formula
  desc "API design, development, and documentation platform"
  homepage "https://apidog.com"
  license "Freeware"

  on_macos do
    on_arm do
      url "https://file-assets.apidog.com/download/Apidog-macOS-arm64-latest.zip"
      sha256 "f0845229a343540c6b93926c2e1115bc7704909b4146bb50ac9ad16456054d9d"
    end
    on_intel do
      url "https://file-assets.apidog.com/download/Apidog-macOS-latest.zip"
      sha256 "4e1d5643a8a12ef4f855b8720c19eaa2f74968854c06e2edc87b86507b8f4fe4"
    end

    version "2.8.40"

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
      sha256 "6df6a3c23bf7ca78a04150056349e7f774a22a9f8d332945ac8e1255d38163e0"
    end
    on_intel do
      url "https://file-assets.apidog.com/download/Apidog-linux-deb-latest.zip"
      sha256 "58eb59f1f50286086daf5d8b81c7e90368158af11731226fdc6170ff401d2ecc"
    end

    version "2.8.40"

    def install
      system "unzip", "-q", pkgfiles.first
      deb = Dir["*.deb"].first
      system "dpkg", "-x", deb, "."
      bin.install "usr/bin/apidog" if File.exist?("usr/bin/apidog")
    end
  end
end
