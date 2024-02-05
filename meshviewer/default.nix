{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.meshviewer;

  meshviewer = pkgs.callPackage ./pkg.nix {};
  configFile = pkgs.writeText "config.json" (builtins.toJSON cfg.config);
in

{

  options.services.meshviewer = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };
    unitName = mkOption {
      type = types.str;
      default = "meshviewer";
      readOnly = true;
      description = "The name of the service.";
    };

    config = mkOption {
      type = types.attrs;
      default = {};
      description = "The name of the config file.";
    };
    nginx = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "configure nginx virtual host";
      };
      hostName = mkOption {
        type = types.str;
        default = "meshviewer.example.org";
        description = "domain to configure nginx for";
      };
      default = mkOption {
        type = types.bool;
        default = true;
        description = "set as default nginx virtual host";
      };
    };
  };

  config = mkIf cfg.enable {

    services.nginx = mkIf cfg.nginx.enable {
      enable = true;
      virtualHosts."${cfg.nginx.hostName}" = {
        default = cfg.nginx.default;
        locations."/".root = "${meshviewer}";
        locations."/".extraConfig = ''
          try_files $uri $uri/ =404;
        '';
        locations."=/config.json".alias = "${configFile}";
      };
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}