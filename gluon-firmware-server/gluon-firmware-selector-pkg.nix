{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2024-04-19";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "gluon-firmware-selector";
    rev = "f8695356c1bca7e34b4a692e959fd0982978303a";
    sha256 = "sha256-jzZLbue3h0wgzlFh10CpNYoWRXyv3WDdyuit9TzwNDw=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
    echo "VERSION=${version}" > $out/version.txt
    echo "REV=${src.rev}" >> $out/version.txt
  '';
}