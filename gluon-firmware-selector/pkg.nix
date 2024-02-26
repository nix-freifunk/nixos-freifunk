{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2024-02-07";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "gluon-firmware-selector";
    rev = "793d1c54f6c64623d919c8db5b0e625387c3365f";
    sha256 = "sha256-xuvJb/TlBZFD29PtnN7azFhPxWpw+PLByAMU+DNqCXE=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
  '';
}
