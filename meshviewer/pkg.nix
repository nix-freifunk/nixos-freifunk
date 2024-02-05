{ stdenv, fetchurl, unzip }:

stdenv.mkDerivation rec {
  pname = "meshviewer";
  version = "12.4.0";

  src = fetchurl {
    url = "https://github.com/freifunk/meshviewer/releases/download/v${version}/meshviewer-build.zip";
    sha256 = "sha256-YZtsckTlQ680+P4QZUq6iPXSqMh3AaYJFeAYdPLepHg=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ unzip ];

  buildPhase = ''
    mkdir -p $out
    cp -r * $out
  '';
}
