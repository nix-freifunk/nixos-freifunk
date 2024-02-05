{ config, lib, pkgs, ... }:

let
  cfg = config.services.meshAnnounce;
  meshAnnounce = pkgs.callPackage ./pkg.nix { };

  python-with-mesh-announce-packages = pkgs.python3.withPackages (p: with p; [
    psutil
  ]);

  dependencies = [ python-with-mesh-announce-packages pkgs.lsb-release pkgs.ethtool pkgs.batctl ];

  customToINI = lib.generators.toINI {
    # specifies how to format a key/value pair
    mkKeyValue = lib.generators.mkKeyValueDefault {
      # specifies the generated string for a subset of nix values
      mkValueString = v:
             if v == true then ''True''
        else if v == false then ''False''
        else if lib.isList v then lib.concatStringsSep ", " v
        else if lib.isInt v then ''${toString v}''
        else if lib.isString v then ''${v}''
        else lib.generators.mkValueStringDefault {} v;
    } ": ";
  };

  removeEmpty = lib.filterAttrs (_: v: v != "" && v != null && v != [] && v != {});
  removeEmptyFromSet = lib.mapAttrs (name: set: removeEmpty set);

  responddConfig = removeEmptyFromSet ({"Defaults" = cfg.defaultConfig; } // cfg.domainConfig);

  confFile = pkgs.writeText "respondd.conf" (customToINI responddConfig);

  makeSharedOptions = defaults: {
    DomainCode = lib.mkOption {
      type = lib.types.str;
      default = defaults.DomainCode or "";
      description = "Domain code.";
    };

    DomainType = lib.mkOption {
      type = lib.types.str;
      default = defaults.Domain or "";
      description = "Domain type.";
    };

    FastdPublicKey = lib.mkOption {
      type = lib.types.str;
      default = defaults.FastdPublicKey or "";
      description = "Fastd public key.";
    };

    WirGuardPublicKey = lib.mkOption {
      type = lib.types.str;
      default = defaults.WirGuardPublicKey or "";
      description = "WireGuard public key.";
    };

    VPNProtocols = lib.mkOption {
      type = lib.types.str;
      default = defaults.VPNProtocols or "";
      description = "VPN protocols.";
    };

    MulticastLinkAddress = lib.mkOption {
      type = lib.types.str;
      default = defaults.MulticastLinkAddress or "";
      description = "Multicast link address.";
    };

    MulticastSiteAddress = lib.mkOption {
      type = lib.types.str;
      default = defaults.MulticastSiteAddress or "";
      description = "Multicast site address.";
    };

    IPv4Gateway = lib.mkOption {
      type = lib.types.str;
      default = defaults.IPv4Gateway or "";
      description = "IPv4 gateway option for ddhcpd.";
    };

    Hostname = lib.mkOption {
      type = lib.types.str;
      default = defaults.Hostname or "";
      description = "Hostname to advertise.";
    };

    Hardware-Model = lib.mkOption {
      type = lib.types.str;
      default = defaults.Hardware-Model or "";
      description = "Hardware used by the system.";
    };

    Contact = lib.mkOption {
      type = lib.types.str;
      default = defaults.Contact or "";
      description = "Contact information of owner.";
    };

    Latitude = lib.mkOption {
      type = lib.types.str;
      default = defaults.Latitude or "";
      description = "Latitude of the system.";
    };

    Longitude = lib.mkOption {
      type = lib.types.str;
      default = defaults.Longitude or "";
      description = "Longitude of the system.";
    };

    VPN = lib.mkOption {
      type = lib.types.bool;
      default = defaults.VPN or true;
      description = "Is the system considered a gateway.";
    };
  };

  globalOptions = makeSharedOptions{}// {
    Port = lib.mkOption {
      type = lib.types.int;
      default = 1001;
      description = "Batman interface.";
    };
    DefaultDomain = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Default domain.";
    };
  };

  domainOptions = makeSharedOptions{} // {
    BatmanInterface = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Batman interface.";
    };

    Interfaces = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      description = "Other listen interfaces.";
    };
  };

  allInterfaces = lib.concatMap (domain: domain.Interfaces ++ [domain.BatmanInterface]) (lib.attrValues cfg.domainConfig);

in
{
  options.services.meshAnnounce = {
    enable = lib.mkEnableOption "mesh-announce service";

    package = lib.mkOption {
      type = lib.types.package;
      default = meshAnnounce;
      description = "The mesh-announce package to use.";
    };

    unitName = lib.mkOption {
      type = lib.types.str;
      default = "mesh-announce";
      description = "The name of the systemd unit.";
    };

    defaultConfig = lib.mkOption {
      type = lib.types.submodule {
        options = globalOptions;
      };
      default = { };
      description = "Default configuration for the mesh-announce service.";
    };

    openFirewall = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Open the firewall for the mesh-announce service.";
    };

    domainConfig = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule { options = domainOptions; });
      default = { };
      description = "Domain configuration for the mesh-announce service.";
    };

    extraConfig = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "configuration for my service.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services."${cfg.unitName}" = {
      description = "Mesh Announce Service";
      after = [ "network.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        ExecStart = "${cfg.package}/bin/respondd.py -f ${confFile}";
        WorkingDirectory = "${cfg.package}/bin/";
        Environment = "PATH=${lib.makeBinPath dependencies}";
      };
    };

    networking.firewall.extraInputRules = lib.mkIf cfg.openFirewall ''
      iifname { ${lib.concatStringsSep ", " allInterfaces} } udp dport ${toString cfg.defaultConfig.Port} counter accept comment "accept mesh-announce"
    '';

  };
}