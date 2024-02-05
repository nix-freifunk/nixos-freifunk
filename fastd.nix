{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.fastd;

  makeFastdJob = value: name: {
    description = "fastd - ${value.description}";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    reload = "${pkgs.util-linux}/bin/kill -HUP $MAINPID";
    #path = [ pkgs.batctl ];
    serviceConfig = {
      ExecStart = "${value.package}/bin/fastd --config ${fastdConf value name}";
      Restart = "always";
    };
  };

  fastdConf = value: name: pkgs.writeText "fastd.conf" ''
    mtu ${toString value.mtu};

    ${concatStringsSep "\n" (map (s: "method \"" + s + "\";") value.method)}

    # include the secret:
    include "${value.secretKeyIncludeFile}";

    status socket "${value.statusSocket}";
    peer limit ${toString value.peerLimit };
    offload l2tp ${if value.l2tpOffload then "yes" else "no"};
    persist interface ${if value.persistInterface then "yes" else "no"};
    ${concatStringsSep "\n" (map (s: "bind " + s + ";") value.bind)}
    ${optionalString (value.mode != "tap") "interface \"${value.interface}\";"}
    mode ${value.mode};
    ${concatMapStrings (x: ''
    include peer "${pkgs.writeText x.name ''
      key "${ x.pubkey }";
      float yes;
      ${concatMapStrings (y: ''
      remote "${ y.address }" port ${toString y.port };
      '') x.remote}
      ${optionalString (builtins.hasAttr "interface" x ) "interface \"${x.interface}\";"}
    ''}" as "${ x.name }";
    '') value.peers}
    ${optionalString (value.peerDir != "") "include peers from \"${value.peerDir}\";" }
    ${optionalString (value.extraConfig != "") value.extraConfig }
  '';
in
{
  options.services.fastd = mkOption {
    type = with types; attrsOf  (submodule({ name, ...}: {
      options = {
        package = mkOption {
          type = types.package;
          default = pkgs.fastd;
          description = "The fastd package to use.";
        };
        unitName = mkOption {
          type = types.str;
          default = "fastd-${name}";
          readOnly = true;
          description = "The name of the service.";
        };
        mode = mkOption {
          type = types.str;
          default =  "tap";
        };
        description = mkOption {
          type = types.str;
          default = "";
        };
        secretKeyIncludeFile = mkOption {
          type = types.str;
          description = ''
            The path to the file that contains the secret key file.
            It's recomended that this file isn't part of the nix store.
            The file has to contain the secret in the format `secret "...";`.
          '';
        };
        peerLimit = mkOption {
          type = types.ints.unsigned;
          default = 1;
        };
        interface = mkOption {
          type = types.str;
          default = "vpn-%n";
        };
        peerDir = mkOption {
          type = types.str;
          default = "";
        };
        peers = mkOption {
          type = listOf attrs;
          default = [];
          example = [
            {
              name = "gw01";
              remote = [
                { address = "gw01.darmstadt.freifunk.net"; port = 10000; }
                { address = "82.195.73.40"; port = 10000; }
                { address = "[2001:67c:2ed8::40:1]"; port = 10000; }
              ];
              pubkey = "e04a2e54f873876ea2fc50973f85743daee7878c1872f905c94b12371fea3b9d";
              interface = "test";
            }
          ];
        };
        mtu = mkOption {
          type = types.ints.unsigned;
          default = 1312;
        };
        bind = mkOption {
          type = listOf str;
          default = [ "any" ];
        };
        method = mkOption {
          type = listOf str;
          default = [ "null@l2tp" "null" ];
        };
        l2tpOffload = mkOption {
          type = types.bool;
          default = false;
        };
        persistInterface = mkOption {
          type = types.bool;
          default = true;
        };
        statusSocket = mkOption {
          type = types.str;
          default = "/run/fastd-${ name }-vpn.sock";
        };
        extraConfig = mkOption {
          type = types.lines;
          default = "";
        };
      };
    }));
    default = {};
    description = "Fastd service configurations.";
  };

  config = mkIf (cfg != {}) {
    systemd.services = listToAttrs (mapAttrsFlatten (name: value: nameValuePair "${value.unitName}" (makeFastdJob value name)) cfg);
  };
}