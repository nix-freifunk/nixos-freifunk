{ stdenv, fetchFromGitHub, unzip }:

stdenv.mkDerivation rec {
  pname = "gluon-firmware-selector";
  version = "0-unstable-2024-10-24";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "gluon-firmware-selector";
    rev = "3a2200771e3832f9f85f34b73442d3161caf3706";
    sha256 = "sha256-LtoqSOZA3aAifFXzDeBw7z4jqRp1lzD4lAEzwqej8jg=";
  };

  sourceRoot = ".";

  buildPhase = ''
    mkdir -p $out
    cp -r source/* $out
    echo "VERSION=${version}" > $out/version.txt
    echo "REV=${src.rev}" >> $out/version.txt
  '';
}
