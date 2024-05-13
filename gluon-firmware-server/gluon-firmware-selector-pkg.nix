{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2024-05-13";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "gluon-firmware-selector";
    rev = "eef379be93725491a32925d526e70d3364ad670a";
    sha256 = "sha256-5xIV5sbDosOtK2tEUqq3dGX1MBrqawaZQfenyHVJq1A=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
    echo "VERSION=${version}" > $out/version.txt
    echo "REV=${src.rev}" >> $out/version.txt
  '';
}