{ lib
, buildGoModule
, fetchFromGitHub
}:

buildGoModule rec {
  pname = "fastd-exporter";
  version = "0-unstable-2024-02-06";

  src = fetchFromGitHub {
    owner = "freifunk-darmstadt";
    repo = "fastd-exporter";
    rev = "fb7aca668ed7d4631be91f05954b9fa1309c0445";
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