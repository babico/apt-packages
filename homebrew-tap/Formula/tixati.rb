class Tixati < Formula
  desc "Feature-rich BitTorrent client"
  homepage "https://tixati.com"
  license "Freeware"

  disable! if OS.mac?

  url "https://download.tixati.com/tixati_3.44-1_amd64.deb"
  sha256 "placeholder"
  version "3.44"

  def install
    system "dpkg", "-x", pkgfiles.first, "."
    bin.install "usr/bin/tixati" if File.exist?("usr/bin/tixati")
  end
end