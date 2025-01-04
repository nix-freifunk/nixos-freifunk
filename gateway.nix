{ pkgs
, lib
, config
, nodes
, nodeName
, name
, ... }:
with lib;

let
  cfg = config.modules.freifunk.gateway;

  getOnlyEnabled = lib.filterAttrs (_: value: value.enable);

  enabledDomains = if cfg.enable then getOnlyEnabled cfg.domains else {};

  enabledDomainsBird = lib.filterAttrs (_: value: value.bird.enable) enabledDomains;

  hasEnabledBirdDomain = lib.any (domain: domain.bird.enable) (lib.attrValues enabledDomains);

  hasEnabledFastdDomain = lib.any (domain: domain.fastd.enable) (lib.attrValues enabledDomains);

  enabledFastdUnits = lib.mapAttrsToList (name: domain: lib.lists.optionals domain.fastd.enable "${config.services.fastd.${name}.unitName}.service") enabledDomains;

  # set of all gw nodes
  gwNodes = lib.filterAttrs (_: node: node.config ? modules && node.config.modules ? freifunk.gateway && node.config.modules.freifunk.gateway.enable) nodes;

  # gw nodes which aren't the current node
  gwNodesOther = lib.filterAttrs (node: _: node != "${name}") gwNodes;

  vxlanPortIpList = (lib.mapAttrsToList (name: value: { dom = "${name}"; port = "${toString value.vxlan.port}"; ips = value.vxlan.remoteLocalsRO;}) enabledDomains);

  intToHex = import ./functions/intToHex.nix { inherit lib; };
in
{

  options.modules.freifunk.gateway = {
    enable = mkEnableOption "ffda gateway";

    outInterfaces = mkOption {
      type = types.listOf types.str;
      description = ''
        Interfaces used to route through from domains.
      '';
      default = [ "enp1s0" ];
    };

    vxlanInterface = mkOption {
      type = types.str;
      description = ''
        Interface used as the base vxlan interfaces.
      '';
      default = builtins.elemAt cfg.outInterfaces 0;
    };

    meta = {
      contact = mkOption {
        type = types.str;
        description = "Contact Information. Announced via respondd if enabled.";
        default = "";
      };
      latitude = mkOption {
        type = types.str;
        description = "Latitude of the server. Announced via respondd if enabled.";
        default = "";
      };
      longitude = mkOption {
        type = types.str;
        description = "Longitude of the server. Announced via respondd if enabled.";
        default = "";
      };
    };

    respondd = {
      enable = mkEnableOption "enable mesh-announce" // { default = true; };
    };

    yanic = {
      enable = mkEnableOption "enable yanic";
      defaultSite = mkOption {
        type = types.str;
        description = "Default site for yanic";
        default = "default";
      };
    };

    fastd = {
      secretKeyIncludeFile = mkOption {
        type = types.str;
        description = ''
          Path to the fastd secret key file.
        '';
        default = "";
      };
      peerDir = mkOption {
        type = types.path;
        description = ''
          Path to the fastd peer directory.
        '';
      };
      peerLimit = mkOption {
        type = types.int;
        description = ''
          Maximum number of peers.
        '';
        default = 20;
      };
    };

    vxlan = {
      local = mkOption {
        type = types.str;
        description = ''
          Local IP address for the vxlan interfaces.
        '';
      };
      interfaceNames = mkOption {
        type = types.listOf types.str;
        description = ''
          List of names for the vxlan interfaces. Can be used to add them to main interface.

          For Example:

          systemd.network.networks."20-mainif".networkConfig.VXLAN = config.modules.freifunk.gateway.vxlan.interfaceNames;
        '';
        default = lib.mapAttrsToList (_: domain: domain.vxlan.interfaceName) enabledDomains;
        readOnly = true;
      };
      port = mkOption {
        type = types.port;
        description = ''
          Port for the vxlan interfaces.
        '';
        default = 4789;
      };
      remoteLocals = mkOption {
        type = types.listOf types.str;
        description = ''
          List of other local IP addresses for the vxlan interface.
        '';
        default = [];
      };
    };

    dnsDomainName = mkOption {
      description = "DNS domain name";
      type = types.str;
      default = "";
    };

    dnsSearchDomain = mkOption {
      description = "DNS search domain";
      type = types.listOf types.str;
      default = [];
    };

    blockTCPPort25 = mkOption {
      description = "Block TCP port 25";
      type = types.bool;
      default = false;
    };

    domains = mkOption {
      type = with types; attrsOf  (submodule({ name, ...}:
      let
        dcfg = cfg.domains.${name};
      in {
        options = {
          enable = mkEnableOption "enable domain" // { default = true; };
          name = mkOption {
            description = "Name of the domain";
            type = types.str;
            default = name;
          };
          id = mkOption {
            description = "ID of the domain";
            type = types.int;
            default = lib.strings.toIntBase10 (lib.strings.removePrefix "dom" name);
          };
          idHex = mkOption {
            description = "ID of the domain as hex representation";
            type = types.str;
            default = intToHex dcfg.id;
          };
          names = mkOption {
            description = "List of names for the domain";
            type = types.attrsOf types.str;
            default = {};
          };
          mtu = mkOption {
            description = "MTU of the domain";
            type = types.int;
            default = 1280;
          };
          dnsDomainName = mkOption {
            description = "DNS domain name";
            type = types.str;
            default = cfg.dnsDomainName;
          };
          dnsSearchDomain = mkOption {
            description = "DNS search domain of the domain";
            type = types.listOf types.str;
            default = cfg.dnsSearchDomain;
          };
          batmanAdvanced = {
            enable = mkEnableOption "start batman-adv for this domain" // { default = true; };
            mac = mkOption {
              type = types.str;
              description = ''
                MAC address of the batman-adv interface.
              '';
            };
            interfaceName = mkOption {
              type = types.str;
              description = ''
                Name of the batman-adv interface.
              '';
              default = "bat-${name}";
              readOnly = true;
            };
            gatewayBandwidthDown = mkOption {
              type = types.str;
              description = ''
                Gateway bandwidth down.
              '';
              default = "100M";
            };
            gatewayBandwidthUp = mkOption {
              type = types.str;
              description = ''
                Gateway bandwidth up.
              '';
              default = "100M";
            };
          };
          vxlan = {
            enable = mkEnableOption "start vxlan for this domain" // { default = true; };
            vni = mkOption {
              type = types.int;
              description = ''
                VXLAN ID
              '';
              default = dcfg.id;
            };
            interfaceName = mkOption {
              type = types.str;
              description = ''
                Name of the vxlan interface.
              '';
              default = "vx-${name}";
              readOnly = true;
            };
            local = mkOption {
              type = types.str;
              description = ''
                Local IP address for the vxlan interface.
              '';
              default = cfg.vxlan.local;
            };
            remoteLocals = mkOption {
              type = types.listOf types.str;
              description = ''
                List of other local IP addresses for the vxlan interface.
              '';
              default = cfg.vxlan.remoteLocals;
            };
            remoteLocalsRO = mkOption {
              type = types.listOf types.str;
              description = ''
                List of all gathered and configured local IP addresses for the vxlan interface.
              '';
              default = builtins.filter (str: str != "") (lib.mapAttrsToList(_: value: (
                # "${if value.dcfg.enable && value.dcfg.vxlan.enable then value.dcfg.vxlan.local else ""}"
                "${if value.config.modules.freifunk.gateway.domains.${name}.enable && value.config.modules.freifunk.gateway.domains.${name}.vxlan.enable then value.config.modules.freifunk.gateway.domains.${name}.vxlan.local else ""}"
              )) gwNodesOther) ++ dcfg.vxlan.remoteLocals;
              readOnly = true;
            };
            port = mkOption {
              type = types.port;
              description = ''
                Port for the vxlan interface.
              '';
              default = cfg.vxlan.port;
            };
          };
          fastd = {
            enable = mkEnableOption "start fastd for this domain" // { default = true; };
            secretKeyIncludeFile = mkOption {
              type = types.str;
              description = ''
                Path to the fastd secret key file.
              '';
              default = cfg.fastd.secretKeyIncludeFile;
            };
            port = mkOption {
              type = types.port;
              description = ''
                Fastd listening port
              '';
              default = 10000 + (dcfg.id * 10);
            };
            peerInterfacePattern = mkOption {
              type = types.str;
              description = ''
                Name of the fastd interface.
              '';
              default = "${name}p-%k";
            };
            peerDir = mkOption {
              type = types.path;
              description = ''
                Path to the fastd peer directory.
              '';
              default = cfg.fastd.peerDir;
            };
            peerLimit = mkOption {
              type = types.int;
              description = ''
                Maximum number of peers.
              '';
              default = cfg.fastd.peerLimit;
            };
            methods = mkOption {
              type = types.listOf types.str;
              description = ''
                List of fastd methods to use.
              '';
              default = [ "null@l2tp" "null" ];
            };
          };
          bird = {
            enable = mkEnableOption "start bird for this domain" // { default = true; };
          };
          ipv4 = {
            enable = mkEnableOption "start ipv4 for this domain" // { default = true; };

            prefixes = mkOption {
              type = with types; attrsOf  (submodule({ name, ...}: {
                options = let
                  pcfg = dcfg.ipv4.prefixes."${name}";
                in {
                  prefix = mkOption {
                    type = types.str;
                    description = ''
                      IPv4 prefix
                    '';
                    default = "${name}";
                  };
                  network = mkOption {
                    type = types.str;
                    description = ''
                      IPv4 Network address of this Prefix.
                    '';
                    default = builtins.elemAt (lib.splitString "/" pcfg.prefix) 0;
                    readOnly = true;
                  };
                  length = mkOption {
                    type = types.str;
                    description = ''
                      Length of this prefix in CIDR notation.
                    '';
                    default = builtins.elemAt (lib.splitString "/" pcfg.prefix) 1;
                    readOnly = true;
                  };
                  addresses = mkOption {
                    type = types.listOf types.str;
                    description = ''
                      List of IPv4 addresses to assign.
                    '';
                    default = [];
                  };
                  addressesCIDR = mkOption {
                    type = types.listOf types.str;
                    description = ''
                      IPv4 address for the current node in CIRDR notation.
                    '';
                    default = map (ip: "${ip}/${pcfg.length}") pcfg.addresses;
                    readOnly = true;
                  };
                };
              }));
              default = {};
            };
            addresses = mkOption {
              type = types.listOf types.str;
              description = ''
                IPv4 address for the current node in CIRDR notation.
              '';
              default = lib.concatMap (prefix: prefix.addresses) (lib.attrValues dcfg.ipv4.prefixes);
              readOnly = true;
            };
            addressesCIDR = mkOption {
              type = types.listOf types.str;
              description = ''
                IPv4 address for the current node in CIRDR notation.
              '';
              default = lib.concatMap (prefix: prefix.addressesCIDR) (lib.attrValues dcfg.ipv4.prefixes);
              readOnly = true;
            };
            dhcpV4 = {
              enable = mkEnableOption "start DHCPv4 server for this domain" // { default = true; };
              dnsServers = mkOption {
                type = types.listOf types.str;
                description = ''
                  List of DNS servers to send to DHCP clients.
                '';
                default = [];
              };
              gateway = mkOption {
                type = types.str;
                description = ''
                  Gateway IP to send to DHCP clients.
                '';
                default = builtins.elemAt dcfg.ipv4.addresses 0;
              };
              pools = mkOption {
                type = types.listOf types.str;
                description = ''
                  List of DHCPv4 pools to use.
                '';
                default = [];
              };
              captivePortalURL = mkOption {
                type = types.str;
                description = ''
                  Value of Option 104 - Captive Portal URL (RFC8910). Defaults to announce an unrestricted network.
                '';
                default = "urn:ietf:params:capport:unrestricted";
              };
            };
          };
          ipv6 = {
            enable = mkEnableOption "start ipv6 for this domain" // { default = true; };
            prefixes = mkOption {
              type = with types; attrsOf  (submodule({ name, ...}: {
                options = let
                  pcfg = dcfg.ipv6.prefixes."${name}";
                in {
                  prefix = mkOption {
                    type = types.str;
                    description = ''
                      IPv6 prefix
                    '';
                    default = "${name}";
                  };
                  network = mkOption {
                    type = types.str;
                    description = ''
                      IPv6 Network address of this Prefix.
                    '';
                    default = builtins.elemAt (lib.splitString "/" pcfg.prefix) 0;
                    readOnly = true;
                  };
                  length = mkOption {
                    type = types.str;
                    description = ''
                      Length of this prefix in CIDR notation.
                    '';
                    default = builtins.elemAt (lib.splitString "/" pcfg.prefix) 1;
                    readOnly = true;
                  };
                  addresses = mkOption {
                    type = types.listOf types.str;
                    description = ''
                      List of IPv6 addresses to assign.
                    '';
                    default = [];
                  };
                  addressesCIDR = mkOption {
                    type = types.listOf types.str;
                    description = ''
                      IPv6 address for the current node in CIRDR notation.
                    '';
                    default = map (ip: "${ip}/${pcfg.length}") pcfg.addresses;
                    readOnly = true;
                  };
                  announce = mkOption {
                    type = types.bool;
                    description = ''
                      Announce this prefix via Router Advertisments.
                    '';
                    default = true;
                  };
                };
              }));
              default = {};
            };
            dnsServers = mkOption {
              type = types.listOf types.str;
              description = ''
                List of DNS servers to send via Router Advertisments
              '';
              default = [];
            };
            addresses = mkOption {
              type = types.listOf types.str;
              description = ''
                IPv4 address for the current node in CIRDR notation.
              '';
              default = lib.concatMap (prefix: prefix.addresses) (lib.attrValues dcfg.ipv6.prefixes);
              readOnly = true;
            };
            addressesCIDR = mkOption {
              type = types.listOf types.str;
              description = ''
                IPv4 address for the current node in CIRDR notation.
              '';
              default = lib.concatMap (prefix: prefix.addressesCIDR) (lib.attrValues dcfg.ipv6.prefixes);
              readOnly = true;
            };
          };
        };
      }));
    };
  };

  imports = [
    ./fastd.nix
    ./bird.nix
    ./fastd-peergroup-nodes.nix
    ./fastd-exporter
    ./firewall
    ./kea
    ./yanic.nix
    ./mesh-announce
  ];

  config = mkIf cfg.enable {

    # boot.kernelPackages = pkgs.linuxPackages_6_5;
    # boot.kernelPackages = pkgs.linuxPackages_5_10;

    boot.extraModulePackages = with config.boot.kernelPackages; [ batman_adv ];

    boot.kernelModules = [
      "nf_conntrack"
    ];

    boot.kernel.sysctl = {
      "net.ipv4.conf.default.rp_filter" = 0;
      "net.ipv4.conf.all.rp_filter" = 0;

      "net.ipv4.conf.all.forwarding" = 1;
      "net.ipv6.conf.all.forwarding" = 1;

      "net.netfilter.nf_conntrack_max" = 256000;

      "net.ipv4.neigh.default.gc_thresh1" = 2048;
      "net.ipv4.neigh.default.gc_thresh2" = 4096;
      "net.ipv4.neigh.default.gc_thresh3" = 8192;

      "net.ipv6.neigh.default.gc_thresh1" = 2048;
      "net.ipv6.neigh.default.gc_thresh2" = 4096;
      "net.ipv6.neigh.default.gc_thresh3" = 8192;

      "net.core.rmem_default" = 8388608;
      "net.core.rmem_max" = 8388608;

      "net.core.wmem_default" = 8388608;
      "net.core.wmem_max" = 8388608;
    };

    services.freifunk.bird = lib.mkIf hasEnabledBirdDomain {
      enable = true;

      extraConfig = ''

        ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (_: domain: ''
          protocol radv radv_${domain.name} {
            propagate routes no;

            ipv6 {
              table master6;
              export all;
              import none;
            };

            interface "${domain.batmanAdvanced.interfaceName}" {
              min delay 3;
              max ra interval 60;
              other config no;
              solicited ra unicast yes;

              ${lib.concatStringsSep "\n    " (builtins.map (ipv6: "prefix "+ipv6.prefix+" { };") (lib.filter (prefix: prefix.announce) (lib.attrValues domain.ipv6.prefixes)))}

              rdnss {
                ${lib.concatStringsSep "\n      " (builtins.map (dnsServer: "ns "+dnsServer+";") domain.ipv6.dnsServers)}
              };

              dnssl {
                ${lib.concatStringsSep "\n      " (builtins.map (dnsSearchDomain: "domain \""+dnsSearchDomain+"\";") domain.dnsSearchDomain)}
              };

              link mtu ${toString (domain.mtu)};
            };

            prefix ::/0 {
              skip;
            };
          }
        '') enabledDomainsBird)}
      '';
    };

    services.freifunk.prometheus.exporters.batmanAdvTextexport = {
      enable = true;
    };

    networking.firewall.allowedUDPPorts = lib.mapAttrsToList
    (name: domain: domain.fastd.port)
    (lib.filterAttrs (_: domain: domain.fastd.enable) enabledDomains);

    nixpkgs.overlays = [(self: super: {
      fastd = super.fastd.overrideAttrs (oldAttrs: {
        version = "22-unstable-2023-08-25";
        src = pkgs.fetchFromGitHub {
          owner  = "neocturne";
          repo = "fastd";
          rev = "2456f767edc67210797ae6a5b8a31aad83ea8296";
          sha256 = "sha256-iSZPBZnZUgcKVRJu/+ckwR1fQJFWGOc1bfWDCd71VlE=";
        };
      });
    })];

    services.fastd-exporter = lib.mkIf hasEnabledFastdDomain {
      enable = true;
      instances = lib.mapAttrs (name: domain: config.services.fastd.${name}.statusSocket) enabledDomains;
    };

    systemd.services.${config.services.fastd-exporter.unitName} = lib.mkIf hasEnabledFastdDomain {
      after = enabledFastdUnits;
    };

    systemd.services.${config.services.fastd-peergroup-nodes.unitNameSetup} = lib.mkIf hasEnabledFastdDomain {
      before = enabledFastdUnits;
      requiredBy = enabledFastdUnits;
    };

    systemd.services.${config.services.fastd-peergroup-nodes.unitName} = lib.mkIf hasEnabledFastdDomain {
      after = enabledFastdUnits ++ [ "${config.services.fastd-peergroup-nodes.unitNameSetup}.service" ];
      requires = enabledFastdUnits ++ [ "${config.services.fastd-peergroup-nodes.unitNameSetup}.service" ];
    };

    services.fastd = mapAttrs
      (_: domain: lib.mkIf domain.fastd.enable {
        description = "Domain ${domain.name}";
        peerLimit = domain.fastd.peerLimit;
        interface = domain.fastd.peerInterfacePattern;
        mode = "multitap";
        peerDir = domain.fastd.peerDir;
        method = domain.fastd.methods;
        bind = [ "any port ${toString domain.fastd.port}" ];
        secretKeyIncludeFile = domain.fastd.secretKeyIncludeFile;
        persistInterface = false;
        l2tpOffload = true;
      })
      enabledDomains;

    systemd.network = mkMerge (attrValues (mapAttrs (_: domain: {
      netdevs = {
        "75-${domain.name}p-peers" = mkIf domain.fastd.enable {
          netdevConfig = {
            Name = "${domain.name}p-peers";
            Kind = "bridge";
          };
          extraConfig = ''
            [Bridge]
            STP=off
          '';
        };
        "70-${domain.batmanAdvanced.interfaceName}" = mkIf domain.batmanAdvanced.enable {
          netdevConfig = {
            Kind = "batadv";
            Name = "${domain.batmanAdvanced.interfaceName}";
            MACAddress = "${domain.batmanAdvanced.mac}";
          };
          batmanAdvancedConfig = {
            GatewayMode = "server";
            OriginatorIntervalSec = "5";
            RoutingAlgorithm = "batman-iv";
            HopPenalty = 60;
          };
          extraConfig = ''
            [BatmanAdvanced]
            GatewayBandwidthDown=${domain.batmanAdvanced.gatewayBandwidthDown}
            GatewayBandwidthUp=${domain.batmanAdvanced.gatewayBandwidthUp}
          '';
        };
        "70-vxlan-${domain.name}" = mkIf domain.vxlan.enable {
          netdevConfig = {
            Kind = "vxlan";
            Name = "${domain.vxlan.interfaceName}";
          };
          vxlanConfig = {
            VNI = domain.vxlan.vni;
            Local = domain.vxlan.local;
            DestinationPort = domain.vxlan.port;
          };
        };
      };
      networks = {
        "77-vpn-${domain.name}-peer" = mkIf domain.fastd.enable {
          matchConfig = {
            Name = "${domain.name}p-*";
          };
          networkConfig = {
            IPv6AcceptRA = false;
            LinkLocalAddressing = "no";
            Bridge = "${config.systemd.network.netdevs."75-${domain.name}p-peers".netdevConfig.Name}";
          };
          extraConfig = ''
            [Bridge]
            Isolated=True
          '';
        };
        "75-${domain.name}p-peers" = mkIf domain.fastd.enable {
          matchConfig = {
            Name = "${config.systemd.network.netdevs."75-${domain.name}p-peers".netdevConfig.Name}";
          };
          networkConfig = {
            IPv6AcceptRA = false;
            BatmanAdvanced = "${domain.batmanAdvanced.interfaceName}";
            LinkLocalAddressing = "ipv6";
          };
          linkConfig = {
            RequiredForOnline = false;
          };
        };
        "70-${domain.batmanAdvanced.interfaceName}" = mkIf domain.batmanAdvanced.enable {
          matchConfig.Name = "${domain.batmanAdvanced.interfaceName}";
          linkConfig = {
            RequiredForOnline = false;
          };
          networkConfig = {
            Address = [] ++ lib.lists.optionals domain.ipv6.enable domain.ipv6.addressesCIDR ++ lib.lists.optionals domain.ipv4.enable domain.ipv4.addressesCIDR;
            IPv6AcceptRA = false;
          };
          DHCP = "no";
          dhcpV4Config = {
            UseDNS = false;
            UseDomains = false;
            # RouteTable = cfg.routeTable;
          };
          extraConfig = ''
            [IPv6AcceptRA]
            UseDNS=false
            DHCPv6Client=false
            UseGateway=true
          '';
        };
        "70-vxlan-${domain.name}" = mkIf domain.vxlan.enable {
          matchConfig.Name = "${domain.vxlan.interfaceName}";
          linkConfig = {
            RequiredForOnline = false;
          };
          networkConfig = {
            DHCP = "no";
            IPv6AcceptRA = false;
            LinkLocalAddressing = "ipv6";
            BatmanAdvanced = lib.mkIf domain.batmanAdvanced.enable "${domain.batmanAdvanced.interfaceName}";
          };
          bridgeFDBs = builtins.map (remoteIp: {
            Destination=remoteIp;
            MACAddress="00:00:00:00:00:00";
          }) domain.vxlan.remoteLocalsRO;
        };
      };
    }) enabledDomains));

    networking.firewall.extraInputRules = builtins.concatStringsSep "\n" (builtins.map (port: lib.optionalString (builtins.length port.ips > 0) ''
      iifname { ${cfg.vxlanInterface} } ip6 saddr { ${lib.concatStringsSep ", " port.ips } } udp dport ${toString port.port} counter accept comment "accept vxlan ${port.dom}"
    '') vxlanPortIpList);


    networking.nftables.tables.mangle.content = ''
      chain forward_extra {
        ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (dname: domain: let
            notCurrentDomain = lib.filterAttrs (name: _: name != dname) enabledDomains;
            notCurrentDomainNames = builtins.attrNames notCurrentDomain;
          in
        ''
          ip version 4 iifname "${domain.batmanAdvanced.interfaceName}" oifname { "${lib.concatStringsSep "\", \"" (cfg.outInterfaces ++ builtins.concatMap (domain: [cfg.domains.${domain}.batmanAdvanced.interfaceName]) notCurrentDomainNames)}" } tcp flags syn / syn,rst counter tcp option maxseg size set 1240 comment "mss clamping - ${domain.name} - v4"
          ip version 4 iifname { "${lib.concatStringsSep "\", \"" (cfg.outInterfaces ++ builtins.concatMap (domain: [cfg.domains.${domain}.batmanAdvanced.interfaceName]) notCurrentDomainNames)}" } oifname "${domain.batmanAdvanced.interfaceName}" tcp flags syn / syn,rst counter tcp option maxseg size set 1240 comment "mss clamping - ${domain.name} - v4"
          ip version 6 iifname "${domain.batmanAdvanced.interfaceName}" oifname { "${lib.concatStringsSep "\", \"" (cfg.outInterfaces ++ builtins.concatMap (domain: [cfg.domains.${domain}.batmanAdvanced.interfaceName]) notCurrentDomainNames)}" } tcp flags syn / syn,rst counter tcp option maxseg size set 1220 comment "mss clamping - ${domain.name} - v6"
          ip version 6 iifname { "${lib.concatStringsSep "\", \"" (cfg.outInterfaces ++ builtins.concatMap (domain: [cfg.domains.${domain}.batmanAdvanced.interfaceName]) notCurrentDomainNames)}" } oifname "${domain.batmanAdvanced.interfaceName}" tcp flags syn / syn,rst counter tcp option maxseg size set 1220 comment "mss clamping - ${domain.name} - v6"
        '') enabledDomains)}
      }
    '';

    services.kea.dhcp4.settings.subnet4 = lib.mapAttrsToList (_: domain: mkIf domain.ipv4.dhcpV4.enable {
      id = (domain.id + 1);
      subnet = domain.ipv4.prefixes."${(builtins.elemAt (lib.attrNames domain.ipv4.prefixes) 0)}".prefix;
      interface = "${domain.batmanAdvanced.interfaceName}";
      option-data = []
        ++ lib.optional (domain.dnsDomainName != "")
          {
            space = "dhcp4";
            name = "domain-name";
            code = 15;
            data = "${domain.dnsDomainName}";
          }
        ++ lib.optional ((builtins.length domain.dnsSearchDomain) != 0)
          {
            space = "dhcp4";
            name = "domain-search";
            code = 119;
            data = "${lib.concatStringsSep ", " domain.dnsSearchDomain}";
          }
        ++ lib.optional ((builtins.length domain.ipv4.dhcpV4.dnsServers) != 0)
          {
            space = "dhcp4";
            name = "domain-name-servers";
            code = 6;
            data = "${lib.concatStringsSep ", " domain.ipv4.dhcpV4.dnsServers}";
          }
        ++ lib.optional (domain.ipv4.dhcpV4.gateway != "")
          {
            space = "dhcp4";
            name = "routers";
            code = 3;
            data = "${domain.ipv4.dhcpV4.gateway}";
          }
        ++ lib.optional (domain.mtu != "")
          {
            space = "dhcp4";
            name = "interface-mtu";
            code = 26;
            data = "${builtins.toString domain.mtu}";
            always-send = true;
          }
        ++ lib.optional (domain.ipv4.dhcpV4.captivePortalURL != "")
          {
            "name" = "v4-captive-portal";
            "data" = "${domain.ipv4.dhcpV4.captivePortalURL}";
          }
      #   ++ [
      #   {
      #     space = "dhcp4";
      #     name = "domain-name";
      #     code = 15;
      #     data = "darmstadt.freifunk.net";
      #   }
      # ]
      ;
      valid-lifetime = 320;
      max-valid-lifetime = 320;
      pools = [] ++ builtins.concatLists (lib.optional ((builtins.length domain.ipv4.dhcpV4.pools) != 0)
        (map (pool: { inherit pool; }) domain.ipv4.dhcpV4.pools)
      );
    }) enabledDomains;

    services.kea.dhcp4.settings.interfaces-config.interfaces = lib.mapAttrsToList (_: domain: mkIf domain.ipv4.dhcpV4.enable
      "${domain.batmanAdvanced.interfaceName}"
    ) enabledDomains;

    networking.firewall.checkReversePath = "loose";

    networking.nftables.tables.nixos-fw = {
      content = ''
        chain input_extra {
          ip version 4 iifname { "mesh*" } udp sport 68 udp dport 67 counter drop comment "drop dhcp: raw mesh"
          ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (_: domain: ''ip version 4 iifname { "${domain.batmanAdvanced.interfaceName}" } udp sport 68 udp dport 67 counter accept comment "accept dhcp: ${domain.name}"'') enabledDomains)}
        }
        chain forward_extra {
          ${lib.concatStringsSep "\n  " (lib.mapAttrsToList (dname: domain: let
            notCurrentDomain = lib.filterAttrs (name: _: name != dname) enabledDomains;
            notCurrentDomainNames = builtins.attrNames notCurrentDomain;
          in
          ''
            ${ if cfg.blockTCPPort25 then ''
            iifname "${domain.batmanAdvanced.interfaceName}" tcp dport 25 counter reject comment "${domain.name}: don't allow smtp"
            iifname "${domain.batmanAdvanced.interfaceName}" tcp sport 25 counter reject comment "${domain.name}: don't allow smtp"
            oifname "${domain.batmanAdvanced.interfaceName}" tcp dport 25 counter reject comment "${domain.name}: don't allow smtp"
            oifname "${domain.batmanAdvanced.interfaceName}" tcp sport 25 counter reject comment "${domain.name}: don't allow smtp"
            '' else "" }

            ip saddr { ${lib.concatStringsSep ", " (lib.mapAttrsToList(name: value: value.prefix) domain.ipv4.prefixes)} } iifname "${domain.batmanAdvanced.interfaceName}" oifname { "${lib.concatStringsSep "\", \"" cfg.outInterfaces}" } counter accept comment "${domain.name}: accept outgoing ipv4"
            ${if (builtins.length notCurrentDomainNames) > 0 then ''
            ip saddr { ${lib.concatStringsSep ", " (builtins.concatMap (domain: lib.attrNames cfg.domains.${domain}.ipv4.prefixes) notCurrentDomainNames)} } ip daddr { ${lib.concatStringsSep ", " (lib.mapAttrsToList(name: value: value.prefix) domain.ipv4.prefixes)} } iifname { "${lib.concatStringsSep "\", \"" (builtins.concatMap (domain: [cfg.domains.${domain}.batmanAdvanced.interfaceName]) notCurrentDomainNames)}" } oifname "${domain.batmanAdvanced.interfaceName}" counter accept comment "${domain.name}: accept from other local domains ipv4"
            '' else "" }
            ip daddr { ${lib.concatStringsSep ", " (lib.mapAttrsToList(name: value: value.prefix) domain.ipv4.prefixes)} } oifname "${domain.batmanAdvanced.interfaceName}" iifname { "${lib.concatStringsSep "\", \"" cfg.outInterfaces}" } ct state established,related counter accept comment "${domain.name}: accept incoming related and established ipv4"
            
            ip6 saddr { ${lib.concatStringsSep ", " (lib.mapAttrsToList(name: value: value.prefix) domain.ipv6.prefixes)} } iifname "${domain.batmanAdvanced.interfaceName}" oifname { "${lib.concatStringsSep "\", \"" cfg.outInterfaces}" } counter accept comment "${domain.name}: accept outgoing ipv6"
            ${if (builtins.length notCurrentDomainNames) > 0 then ''
            ip6 saddr { ${lib.concatStringsSep ", " (builtins.concatMap (domain: lib.attrNames cfg.domains.${domain}.ipv6.prefixes) notCurrentDomainNames)} } ip6 daddr { ${lib.concatStringsSep ", " (lib.mapAttrsToList(name: value: value.prefix) domain.ipv6.prefixes)} } iifname { "${lib.concatStringsSep "\", \"" (builtins.concatMap (domain: [cfg.domains.${domain}.batmanAdvanced.interfaceName]) notCurrentDomainNames)}" } oifname "${domain.batmanAdvanced.interfaceName}" counter accept comment "${domain.name}: accept from other local domains ipv6"
            '' else "" }
            # ip6 daddr { ${lib.concatStringsSep ", " (lib.mapAttrsToList(name: value: value.prefix) domain.ipv6.prefixes)} } oifname "${domain.batmanAdvanced.interfaceName}" iifname { "${lib.concatStringsSep "\", \"" cfg.outInterfaces}" } ct state established,related counter accept comment "${domain.name}: accept incoming related and established ipv6"
            ip6 daddr { ${lib.concatStringsSep ", " (lib.mapAttrsToList(name: value: value.prefix) domain.ipv6.prefixes)} } oifname "${domain.batmanAdvanced.interfaceName}" iifname { "${lib.concatStringsSep "\", \"" cfg.outInterfaces}" } counter accept comment "${domain.name}: accept incoming ipv6"
          '') enabledDomains)}
        }
      '';
    };

    services.yanic = {
      enable  = cfg.yanic.enable;
      settings = {
        respondd = {
          enable = true;
          synchronize = "1m";
          collect_interval = "1m";
          sites = {
            "${cfg.yanic.defaultSite}" = {
              domains = builtins.concatMap (attrSet: builtins.attrNames attrSet) (lib.mapAttrsToList (name: value: value.names) enabledDomains);
            };
          };
          interfaces = builtins.map (domain: {
            ifname = "${domain.batmanAdvanced.interfaceName}";
            multicast_address = "ff05::2:1001";
            port = 10001;
          }) (builtins.attrValues enabledDomains);
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
            meshviewer-ffrgb = [
              {
                enable = true;
                path = "/var/www/html/meshviewer/data/meshviewer.json";
                filter = {
                  no_owner = true;
                };
              }
            ];
          };
        };
        database = {
          delete_after = "7d";
          delete_interval = "1h";
        };
      };
    };

    systemd.services.yanic.preStart = mkIf cfg.yanic.enable ''
      ${pkgs.coreutils}/bin/mkdir -p /var/www/html/meshviewer/data/
      ${pkgs.coreutils}/bin/mkdir -p /var/lib/yanic/
    '';

    services.meshAnnounce = mkIf cfg.respondd.enable {
      enable = true;
      openFirewall = true;
      defaultConfig = {
        # DefaultDomain = "dom0";
        DomainType = "batadv";
        Contact = cfg.meta.contact;
        VPN = false;
        Latitude = cfg.meta.latitude;
        Longitude = cfg.meta.longitude;
      };

      domainConfig = lib.mapAttrs' (domain: value: {
        name = domain;
        value = {
          BatmanInterface = value.batmanAdvanced.interfaceName;
          Interfaces = [
            "${value.name}p-peers"
            "vx-${value.name}"
          ];
          Hostname = "${value.name}.${if (config.networking.domain or null) != null then config.networking.fqdn else config.networking.hostName}";
          VPN = value.fastd.enable;
        };
      }) enabledDomains;
    };
  };
}
