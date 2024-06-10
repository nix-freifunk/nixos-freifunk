{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.freifunk.bird;
in
{
  options.services.freifunk.bird = {
    enable = lib.mkEnableOption "Enable Bird";
    extraConfig = lib.mkOption {
      type = types.str;
      default = "";
    };
    routerId = lib.mkOption {
      type = types.str;
    };
    localAdresses = lib.mkOption {
      type = types.listOf types.str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    systemd.network = {
      netdevs = {
        "80-dummy0" = {
          netdevConfig = {
            Name = "dummy0";
            Kind = "dummy";
          };
        };

      };
      networks = {
        "80-dummy0" = {
          matchConfig = {
            Name = "dummy0";
          };
          networkConfig = {
            Address = cfg.localAdresses;
            LinkLocalAddressing = "no";
          };
          linkConfig = {
            RequiredForOnline = false;
          };
        };
      };
    };
    services.bird2 = {
      enable = true;
      config = ''
        log syslog all;

        ipv4 table master4;
        ipv6 table master6;

        router id ${cfg.routerId};

        protocol device {
        }

        define RFC1918 = [
          10.0.0.0/8+,
          172.16.0.0/12+,
          192.168.0.0/16+
        ];

        define RFC4193 = [
          fd00::/8+
        ];

        function accept_default_route4() {
          if net = 0.0.0.0/0 then {
            print "Accept (Proto: ", proto, "): ", net, " default route allowed from ", from, " ", bgp_path;
            accept;
          }
        }

        function accept_not_default_route4() {
          if net != 0.0.0.0/0 then {
            accept;
          }
        }

        function accept_default_route6() {
          if net = ::/0 then {
            print "Accept (Proto: ", proto, "): ", net, " default route allowed from ", from, " ", bgp_path;
            accept;
          }
        }

        function accept_not_default_route6() {
          if net != ::/0 then {
            accept;
          }
        }

        ${cfg.extraConfig}
      '';
    };
  };
}
