{ stdenv, fetchFromGitHub, python3Packages }:

stdenv.mkDerivation rec {
  pname = "mesh-announce";
  version = "0-unstable-2024-06-08";

  src = fetchFromGitHub {
    owner = "Freifunk-Rhein-Neckar";
    repo = pname;
    rev = "4105913ce5a78972a92ffe35800f46639bf73771";
    sha256 = "sha256-kPQErmAYNU6rHPgRmXYFFDUqRq4y21tPuPKVsl0TlWM=";
  };

  buildInputs = [ python3Packages.python ];

  installPhase = ''
    mkdir -p $out/bin
    cp *.py $out/bin
    cp *.nix $out/bin
    cp -r providers/ $out/bin
  '';
}