{ lib, config, pkgs, ... }:
let
  cfg = config.services.freifunk.prometheus.exporters.batmanAdvTextexport;
in
{
  options.services.freifunk.prometheus.exporters.batmanAdvTextexport = {
    enable = lib.mkEnableOption "Enable Prometheus textfile exporter for batman-adv.";

    textfileDirectory = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/prometheus-node-exporter";
      description = "Directory for Prometheus textfile collector.";
    };

    textfileName = lib.mkOption {
      type = lib.types.str;
      default = "batadv.prom";
      description = "Filename for Prometheus textfile collector.";
    };

    onCalendar = lib.mkOption {
      type = lib.types.str;
      default = "Minutely";
      description = "Run prometheus exporter batadv-textexport script periodically";
    };

    interfacePattern = lib.mkOption {
      type = lib.types.str;
      default = "bat-dom*";
      description = "Pattern for batman-adv interfaces";
    };
  };

  config = lib.mkIf cfg.enable {
    services.prometheus.exporters.node = {
      enabledCollectors = [
        "textfile"
      ];
      extraFlags = [
        "--collector.textfile.directory=${cfg.textfileDirectory}"
      ];
    };

    systemd.services.prometheus-batadv-textexport = {
      description = "Run prometheus exporter batadv-textexport script";
      serviceConfig = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.busybox}/bin/mkdir -p ${cfg.textfileDirectory}";
        ExecStart = "${pkgs.bash}/bin/sh -c \"${pkgs.writeScript "prometheus-batadv-textexport" ''
          #!${pkgs.bash}/bin/sh
          BATCTL=${pkgs.batctl}/bin/batctl

          for batdev in /sys/class/net/${cfg.interfacePattern}; do
            test -d $batdev || exit 0
            batdev=$(basename $batdev)
            ${pkgs.ethtool}/bin/ethtool  -S $batdev | ${pkgs.busybox}/bin/awk -v batdev=$batdev '
              /^     .*:/ {
                gsub(":", "");
                print "batman_" $1 "{batdev=\"" batdev "\"} " $2
              }
            '

            echo "batman_originator_count{batdev=\"$batdev\",selected=\"false\"}" $($BATCTL meshif $batdev o | ${pkgs.busybox}/bin/egrep '^   ' | ${pkgs.busybox}/bin/wc -l)
            echo "batman_originator_count{batdev=\"$batdev\",selected=\"true\"}" $($BATCTL meshif $batdev o | ${pkgs.busybox}/bin/egrep '^ \*' | ${pkgs.busybox}/bin/wc -l)
            echo "batman_tg_count{batdev=\"$batdev\",type=\"multicast\"}" $(($($BATCTL meshif $batdev tg -m | ${pkgs.busybox}/bin/wc -l) - 2))
            echo "batman_tg_count{batdev=\"$batdev\",type=\"unicast\"}" $(($($BATCTL meshif $batdev tg -u | ${pkgs.busybox}/bin/wc -l) - 2))
          done
        ''} > ${cfg.textfileDirectory}/${cfg.textfileName}\"";
      };
    };

    systemd.timers.prometheus-batadv-textexport = {
      description = "Run prometheus exporter batadv-textexport script periodically";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnCalendar = "${cfg.onCalendar}";
      };
    };
  };
}
