{ config, pkgs, lib, ...}:
with lib;

let
  cfg = config.services.fastd-peergroup-nodes;

in
{
  options.services.fastd-peergroup-nodes = {
    enable = mkEnableOption "fastd peergroup nodes sync service";

    repoUrl = mkOption {
      type = types.str;
      example = "https://github.com/nix-freifunk/fastd-keys.git";
      description = "The repo that should be synced.";
    };

    repoBranch = mkOption {
      type = types.str;
      default = "main";
      description = "The repo branch that should be synced.";
    };

    reloadServices = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The services that should be reloaded if something changed.";
    };

    peerDir = mkOption {
      type = types.path;
      default = "/var/lib/fastd/peer_groups/nodes";
      description = "The path to where to keep the nodes dir.";
    };

    timerEnable = mkOption {
      type = types.bool;
      description = "fastd peergroup nodes sync timer";
      default = true;
    };

    timerIntervall = mkOption {
      type = types.str;
      default = "*-*-* *:0/5:00";
      description = "The intervall in which the sync should be run. Default is every 5 minutes.";
    };

    timerRandomDelay = mkOption {
      type = types.str;
      default = "4m";
      description = "Add a random delay to the timer.";
    };

    timerFixedRandomDelay = mkOption {
      type = types.bool;
      default = true;
      description = "Add a random delay to the timer.";
    };

    unitName = mkOption {
      type = types.str;
      default = "fastd-peergroup-nodes";
      readOnly = true;
      description = "The name of the periodic reload service.";
    };

    unitNameSetup = mkOption {
      type = types.str;
      default = "${cfg.unitName}-setup";
      readOnly = true;
      description = "The name of the service to conditionally create the peer dir.";
    };

    sshCommand = mkOption {
      type = types.str;
      default = "${pkgs.openssh}/bin/ssh";
      description = "The ssh command to use.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services."${cfg.unitNameSetup}" = {
      serviceConfig.Type = "oneshot";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      script = ''
        set -x

        export GIT_COMMITTER_NAME="system"
        export GIT_COMMITTER_EMAIL="info@example.org"
        export GIT_SSH_COMMAND="${cfg.sshCommand}"

        PEER_DIR="${cfg.peerDir}"

        BIN_MKDIR=("${pkgs.coreutils}/bin/mkdir")
        BIN_GIT=("${pkgs.git}/bin/git -C $PEER_DIR")

        if [ ! -d "$PEER_DIR" ]; then
          $BIN_MKDIR --parents $PEER_DIR
          $BIN_GIT init --initial-branch=main

          $BIN_GIT commit --allow-empty -m "init" --author "$GIT_COMMITTER_NAME <$GIT_COMMITTER_EMAIL>"

          $BIN_GIT remote add origin ${cfg.repoUrl}
          $BIN_GIT fetch origin
          $BIN_GIT checkout -b master --track origin/${cfg.repoBranch}
        fi
      '';
    };

    systemd.services."${cfg.unitName}" = {
      serviceConfig.Type = "oneshot";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      script = ''
        set -x

        export GIT_SSH_COMMAND="${cfg.sshCommand}"

        BIN_GIT=("${pkgs.git}/bin/git -C ${cfg.peerDir}")
        BIN_SYSTEMCTL=("${pkgs.systemd}/bin/systemctl")
        BIN_ECHO=("${pkgs.coreutils}/bin/echo")

        HEAD_PRE=$($BIN_GIT rev-parse HEAD || echo 0)

        $BIN_GIT remote set-url origin ${cfg.repoUrl}
        $BIN_GIT fetch origin --prune

        $BIN_GIT branch --move --force ${cfg.repoBranch}
        $BIN_GIT branch --set-upstream-to=origin/${cfg.repoBranch}
        $BIN_GIT reset --hard origin/${cfg.repoBranch} --

        HEAD_POST=$($BIN_GIT rev-parse HEAD)

        if [ "$HEAD_PRE" != "$HEAD_POST" ]; then
          $BIN_ECHO "changes detected, reloading services"
          ${concatMapStringsSep "\n  " (service: "$BIN_SYSTEMCTL is-active --quiet ${service} && $BIN_SYSTEMCTL reload ${service}") cfg.reloadServices}
        fi

        exit 0
      '';
    };
    systemd.timers."${cfg.unitName}" = mkIf cfg.timerEnable {
      wantedBy = [ "timers.target" ];
      partOf = [ "fastd-peergroup-nodes.service" ];
      timerConfig = {
        OnCalendar = [ "${cfg.timerIntervall}" ];
        RandomizedDelaySec = "${cfg.timerRandomDelay}";
        FixedRandomDelay = cfg.timerFixedRandomDelay;
      };
    };
  };
}