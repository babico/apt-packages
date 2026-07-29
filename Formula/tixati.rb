class Tixati < Formula
  desc "Feature-rich BitTorrent client"
  homepage "https://tixati.com"
  license "Freeware"

  disable! if OS.mac?

  url "https://download.tixati.com/tixati_3.44-1_amd64.deb"
  sha256 "d61eef3d932e77c4a93f4bf77975090532aa41cd76516f22cd601589310c2f68"
  version "3.44"

  def install
    system "dpkg", "-x", pkgfiles.first, "."
    bin.install "usr/bin/tixati" if File.exist?("usr/bin/tixati")
  end
end
