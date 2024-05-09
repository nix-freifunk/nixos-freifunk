{ config, pkgs, lib, ...}:
{
  imports = [
    ./meshviewer
    ./tile-server-proxy.nix
    ./gateway.nix
    ./yanic.nix
    ./gluon-firmware-server
  ];

  # Delay nginx startup until network is up, should help with proxy hostname resolution
  systemd.services.nginx = lib.mkIf config.services.nginx.enable {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
  };

}