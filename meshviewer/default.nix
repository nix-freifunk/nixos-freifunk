{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.freifunk.meshviewer;

  meshviewerPkg = pkgs.callPackage ./pkg.nix {};
  configFile = pkgs.writeText "config.json" (builtins.toJSON cfg.config);
in

{

  options.services.freifunk.meshviewer = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    enableSSL = mkOption {
      type = types.bool;
      default = false;
      description = "Enable SSL for the meshviewer vhost";
    };

    useACMEHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The host to use for ACME";
    };

    config = mkOption {
      type = types.attrs;
      default = {};
      description = "The meshviewer config.";
    };

    domain = mkOption {
      type = types.str;
      example = "meshviewer.example.org";
      description = "The domain to use for the meshviewer vhost";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "open firewall for nginx";
    };
  };

  config = mkIf cfg.enable {

    services.nginx = {
      enable = lib.mkDefault true;
      virtualHosts."${cfg.domain}" = {
        locations."/".root = "${meshviewerPkg}";
        locations."/".extraConfig = ''
          try_files $uri $uri/ =404;
        '';
        locations."=/config.json".alias = "${configFile}";

        forceSSL = cfg.enableSSL;
        useACMEHost = cfg.useACMEHost;
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 80 443 ];
  };
}