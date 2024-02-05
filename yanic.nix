{ config, lib, pkgs, ... }:
with lib;

let

  cfg = config.services.yanic;

  tomlFormat = pkgs.formats.toml { };

  confFile = tomlFormat.generate "yanic.conf" cfg.settings;

  allInterfaces = builtins.map (interface: interface.ifname) cfg.settings.respondd.interfaces;

  interfacesByPort = lib.groupBy (interface: (toString interface.port)) cfg.settings.respondd.interfaces;

  portsByInterfaces = builtins.map (port: {
    port = port;
    ifnames = builtins.map (interface: interface.ifname) interfacesByPort.${port};
  }) (builtins.attrNames interfacesByPort);

in

{

  options.services.yanic = {
    enable = mkEnableOption "Enable yanic service";
    autostart = mkOption {
      type = types.bool;
      default = false;
      description = "Start yanic service on boot";
    };
    unitName = mkOption {
      type = types.str;
      default = "yanic";
      readOnly = true;
      description = "name of the started service.";
    };
    settings = mkOption {
      type = tomlFormat.type;
      default = { };
      description = "The configuration of yanic.";
      example = {
        respondd = {
          enable = true;
          synchronize = "1m";
          collect_interval = "1m";
          sites = {
            ffhb = {
              domains = [
                "city"
              ];
            };
          };
          interfaces = [
            {
              ifname = "br-ffhb";
              multicast_address = "fd2f:5119:f2d::5";
            }
            {
              ifname = "bat-dom0";
              multicast_address = "ff05::2:1001";
              port = 10001;
            }
          ];
        };
        webserver = {
          enable = false;
          bind = "127.0.0.1:8080";
        };
        nodes = {
          state_path = "/var/lib/yanic/state.json";
          prune_after = "7d";
          save_interval = "5s";
          offline_after = "10m";
          output = {
            geojson = [
              {
                enable = true;
                path = "/var/www/html/meshviewer/data/nodes.geojson";
              }
            ];
            meshviewer-ffrgb = [
              {
                enable = true;
                path = "/var/www/html/meshviewer/data/meshviewer.json";
                filter = {
                  no_owner = false;
                };
              }
            ];
            meshviewer = [
              {
                enable = true;
                version = 2;
                nodes_path = "/var/www/html/meshviewer/data/nodes.json";
                graph_path = "/var/www/html/meshviewer/data/graph.json";
                filter = {
                  no_owner = false;
                };
              }
            ];
            nodelist = [
              {
                enable = true;
                path = "/var/www/html/meshviewer/data/nodelist.json";
                filter = {
                  no_owner = false;
                };
              }
            ];
            prometheus-sd = [
              {
                enable = true;
                path = "/var/www/html/meshviewer/data/prometheus-sd.json";
                target_address = "ip";
              }
            ];
            raw = [
              {
                enable = true;
                path = "/var/www/html/meshviewer/data/raw.json";
                filter = {
                  no_owner = false;
                };
              }
            ];
          };
        };
        database = {
          delete_after = "7d";
          delete_interval = "1h";
          connection = {
            influxdb = [
              {
                enable = false;
                address = "http://localhost:8086";
                database = "ffhb";
                username = "";
                password = "";
                tags = {
                  hosts = "ffhb";
                  service = "yanic";
                };
              }
            ];
            graphite = [
              {
                enable = false;
                address = "localhost:2003";
                prefix = "freifunk";
              }
            ];
            respondd = [
              {
                enable = false;
                type = "udp6";
                address = "stats.bremen.freifunk.net:11001";
              }
            ];
            logging = [
              {
                enable = false;
                path = "/var/log/yanic.log";
              }
            ];
          };
        };
      };
    };
  };

  config = mkIf cfg.enable {
    systemd.services.${cfg.unitName} = {
      description = "Yet another node info collector";
      wantedBy = lib.mkIf (cfg.autostart) [ "multi-user.target" ];
      after = [ "network.target" ];
      serviceConfig = {
        ExecStart = "${pkgs.yanic}/bin/yanic serve --config ${confFile}";
        Restart = "always";
        RestartSec = "30s";
      };
    };

    networking.firewall.extraInputRules = builtins.concatStringsSep "\n" (builtins.map (port: ''
      iifname { ${builtins.concatStringsSep ", " port.ifnames} } udp dport ${toString port.port} counter accept comment "accept yanic"
    '') portsByInterfaces);

  };
}