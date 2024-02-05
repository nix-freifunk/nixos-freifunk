{ stdenv, fetchFromGitHub, python3Packages }:

stdenv.mkDerivation rec {
  pname = "mesh-announce";
  version = "0-unstable-2023-03-19";

  src = fetchFromGitHub {
    owner = "Freifunk-Rhein-Neckar";
    repo = pname;
    rev = "4454451dde31bcfc3a8279d28fef4a33628d2c65";
    sha256 = "sha256-znl9J667zVDjHOAH85HtrlL3lgmTpzkuLHHmEmqlF/w=";
  };

  buildInputs = [ python3Packages.python ];

  installPhase = ''
    mkdir -p $out/bin
    cp *.py $out/bin
    cp *.nix $out/bin
    cp -r providers/ $out/bin
  '';
}