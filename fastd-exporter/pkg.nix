{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "fastd-exporter";
  version = "0-unstable-2022-04-27";

  src = fetchFromGitHub {
    owner = "herbetom";
    repo = "fastd-exporter";
    rev = "0f5ea9a33292c29c13ff1baff06ae596711b80a6";
    sha256 = "sha256-34GHNOvqoGmY2qwjViX5hza9MiLC3DahbL/DUfzkcGY=";
  };

  ldflags = [ "-s" "-w" ];

  vendorHash = "sha256-huejHEfTJHhdvoCy4Qz+gpbKyrHCTgTzdw6tu0FlIp0=";

  meta = with lib; {
    description = "prometheus exporter for fastd";
    homepage = "https://github.com/freifunk-darmstadt/fastd-exporter";
    license = licenses.mit;
    mainProgram = "fastd-exporter";
  };
}