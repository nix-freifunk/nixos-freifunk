{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2024-02-07";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "gluon-firmware-selector";
    rev = "ce80879e5517711277ca6f368601c81ff6203042";
    sha256 = "sha256-DDt5KZ28whWyRsnjA3C/v+eRIn3F/k5Cu928Sa1ObtY=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
  '';
}
