{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2024-03-05";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "gluon-firmware-selector";
    rev = "c3dabe84156e2605f8daad26057d718cb934c5cb";
    sha256 = "sha256-isAV4f4vy6iVje9JDMHmdAy+a6q96pbmiGg7PYYKOz8=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
  '';
}
