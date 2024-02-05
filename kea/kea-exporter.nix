{ config, pkgs, ... }:

{

  services.prometheus.exporters.kea = {
    enable = true;
    listenAddress = "::";
    controlSocketPaths = [
      "${config.services.kea.dhcp4.settings.control-socket.socket-name}"
    ];
  };

  networking.nftables.tables.nixos-fw = {
    content = ''
      chain input_extra {
        tcp dport ${toString config.services.prometheus.exporters.kea.port} ip saddr { 82.195.73.4, 10.223.254.14 } counter accept comment "prometheus-kea-exporter: accept from elsa"
        tcp dport ${toString config.services.prometheus.exporters.kea.port} ip6 saddr { 2001:67c:2ed8::4:1, fd01:67c:2ed8:a::14:1 } counter accept comment "prometheus-kea-exporter: accept from elsa"
      }
    '';
  };

}