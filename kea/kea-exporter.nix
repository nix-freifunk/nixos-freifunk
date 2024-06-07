{ config, pkgs, ... }:

{

  services.prometheus.exporters.kea = {
    enable = true;
    listenAddress = "::";
    targets = [
      "${config.services.kea.dhcp4.settings.control-socket.socket-name}"
    ];
  };
}