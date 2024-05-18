{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.freifunk.gluon-firmware-server;

  firmwareSelector-pkg = pkgs.callPackage ./gluon-firmware-selector-pkg.nix {};
  firmwareSelector-configFile = pkgs.writeText "config.js" ''
    var config = JSON.parse('${builtins.toJSON cfg.firmwareSelectorServer.config}');

    if (config.vendormodels in window) {
      config.vendormodels = window[config.vendormodels];
    }

    var directoriesEntries = Object.entries(config.directories);

    directoriesEntries.sort(function(a, b) {
      if (a[1] === config.recommended_branch) {
        return -1;
      } else if (b[1] === config.recommended_branch) {
        return 1;
      } else {
        var indexA = config.experimental_branches.indexOf(a[1]);
        var indexB = config.experimental_branches.indexOf(b[1]);

        console.log("sort: ", indexA," ", indexB," ", a[1], " ", b[1])

        if (indexA === -1) {
          indexA = Infinity; // Put entries not in experimental_branches at the end
          indexA = 0;
        }
        if (indexB === -1) {
          indexB = Infinity; // Put entries not in experimental_branches at the end
          indexB = 0;
        }

        return indexA - indexB;
      }
      // if (config.experimental_branches.includes(a[1])) {
      //   return 1;
      // } else if (config.experimental_branches.includes(b[1])) {
      //   return -1;
      // } else {
      //   return 0;
      // }
    });

    config.directories = Object.fromEntries(directoriesEntries);
  '';

in

{

  options.services.freifunk.gluon-firmware-server = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    enableSSL = mkOption {
      type = types.bool;
      default = false;
      description = "Enable SSL for the firmware server where possible";
    };

    useACMEHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The host to use for ACME";
    };

    firmwareSelectorServer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the firmware selector";
      };
      enableSSL = mkOption {
        type = types.bool;
        default = cfg.enableSSL;
        description = "Enable SSL for the firmware selector";
      };

      useACMEHost = mkOption {
        type = types.nullOr types.str;
        default = cfg.useACMEHost;
        description = "The host to use for ACME";
      };

      config = mkOption {
        type = types.attrs;
        example = {
          listMissingImages = false;
          vendormodels = "vendormodels";
          enabled_device_categories = ["recommended"];
          recommended_toggle = false;
          recommended_info_link = null;
          community_prefix = "gluon-ffda-";
          version_regex = "-([0-9]+.[0-9]+.[0-9]+([+-~][0-9]+)?)[.-]";
          directories = {
            "./images/stable/gluon-factory-example.html" = "stable";
            "./images/stable/gluon-other-example.html" = "stable";
            "./images/stable/gluon-sysupgrade-example.html" = "stable";
            "./images/beta/gluon-factory-example.html" = "beta";
            "./images/beta/gluon-other-example.html" = "beta";
            "./images/beta/gluon-sysupgrade-example.html" = "beta";
            "./images/testing/gluon-factory-example.html" = "testing";
            "./images/testing/gluon-other-example.html" = "testing";
            "./images/testing/gluon-sysupgrade-example.html" = "testing";
          };
          title = "Firmware";
          branch_descriptions = {
            stable = "Gut getestet, zuverlässig und stabil.";
            beta = "Vorabtests neuer Stable-Kandidaten.";
            testing = "Ungetestet, automatisch generiert.";
          };
          recommended_branch = "stable";
          experimental_branches = ["experimental"];
          preview_pictures = "pictures/";
          changelog = "CHANGELOG.html";
        };
        description = "The config for the gluon-firmware-selector.";
      };

      package = mkOption {
        type = types.package;
        default = firmwareSelector-pkg;
        description = "The package to use";
      };

      domain = mkOption {
        type = types.str;
        example = "firmware.example.org";
        description = "domain to configure nginx for";
      };

    };

    autoupdaterServer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the autoupdater web server";
      };

      domain = mkOption {
        type = types.str;
        example = "autoupdater.example.org";
        description = "domain to configure nginx for";
      };

      enableSSL = mkOption {
        type = types.bool;
        default = cfg.enableSSL;
        description = "Enable SSL for the autoupdater server";
      };

      useACMEHost = mkOption {
        type = types.nullOr types.str;
        default = cfg.useACMEHost;
        description = "The host to use for ACME";
      };
    };

    packageServer = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the autoupdater web server";
      };

      domain = mkOption {
        type = types.str;
        example = "opkg.example.org";
        description = "domain to configure nginx for";
      };

      enableSSL = mkOption {
        type = types.bool;
        default = cfg.enableSSL;
        description = "Enable SSL for the package server";
      };

      useACMEHost = mkOption {
        type = types.nullOr types.str;
        default = cfg.useACMEHost;
        description = "The host to use for ACME";
      };

      proxyOpenWrtFeedEnable = mkOption {
        type = types.bool;
        default = false;
        description = "Proxy the OpenWrt feed";
      };
      proxyOpenWrtFeedAllowedAddrs = mkOption {
        type = types.listOf types.str;
        default = [];
        example = [ "0.0.0.0/0" "::/0" ];
        description = "The allowed addresses for accessing the OpenWrt feed";
      };
      proxyOpenWrtFeedDeniedAddrs = mkOption {
        type = types.listOf types.str;
        example = [ "192.0.2.0/24" "2001:db8::/32" ];
        default = [ "all" ];
        description = "The denied addresses for accessing the OpenWrt feed";
      };
    };

    uploadUser = mkOption {
      type = types.str;
      default = "firmware";
      description = "The user to upload firmware images";
    };

    uploadUserAuthorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [];
      description = "The authorized keys for the upload user";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "open firewall for nginx";
    };
  };

  config = mkIf cfg.enable {

    services.nginx = {
      enable = true;
      virtualHosts = mkMerge [
        (mkIf cfg.firmwareSelectorServer.enable {
          "${cfg.firmwareSelectorServer.domain}" = {
            locations."/".root = "${cfg.firmwareSelectorServer.package}";
            locations."/".extraConfig = ''
              try_files $uri $uri/ =404;
            '';
            locations."=/config.js" = {
              alias = "${firmwareSelector-configFile}";
              extraConfig = ''
                add_header Last-Modified $date_gmt;
                if_modified_since off;
                expires off;
                etag off;
              '';
            };
            locations."= /images".return = "301 /images/";
            locations."/images/" = {
              alias = "${config.users.users.firmware.home}/images/";
              extraConfig = ''
                autoindex on;
                add_header Access-Control-Allow-Origin *;
              '';
            };
            onlySSL = cfg.firmwareSelectorServer.enableSSL;
            useACMEHost = cfg.firmwareSelectorServer.useACMEHost;
          };
          "${cfg.firmwareSelectorServer.domain}-no-ssl" = mkIf cfg.firmwareSelectorServer.enableSSL {
            serverName = cfg.firmwareSelectorServer.domain;
            locations."= /images" = config.services.nginx.virtualHosts."${cfg.firmwareSelectorServer.domain}".locations."= /images";
            locations."/images/" = config.services.nginx.virtualHosts."${cfg.firmwareSelectorServer.domain}".locations."/images/";
            locations."/" = {
              return = "301 https://$host$request_uri";
            };
          };
        })
        (mkIf cfg.autoupdaterServer.enable {
          "${cfg.autoupdaterServer.domain}" = {
            locations."/" = {
              root = "${config.users.users.firmware.home}/images/";
              extraConfig = ''
                autoindex on;
              '';
            };
            addSSL = cfg.autoupdaterServer.enableSSL;
            useACMEHost = cfg.autoupdaterServer.useACMEHost;
          };
        })
        (mkIf cfg.packageServer.enable {
          "${cfg.packageServer.domain}" = {
            locations."=/" = {
              return = "200 \"<!DOCTYPE html><h1>OPKG</h1><ul><li><a href=\\\"/modules/\\\">modules</a></li>" + (if cfg.packageServer.proxyOpenWrtFeedEnable then "<li><a href=\\\"/openwrt/\\\">openwrt</a></li>" else "") + "</ul>\"";
              extraConfig = "default_type text/html;";
            };
            locations."/openwrt/" = mkIf cfg.packageServer.proxyOpenWrtFeedEnable {
              return = "302 /openwrt/releases/";
            };
            locations."/releases/" = mkIf cfg.packageServer.proxyOpenWrtFeedEnable {
              return = "302 /openwrt/releases/";
            };
            locations."/openwrt/releases/" = mkIf cfg.packageServer.proxyOpenWrtFeedEnable {
              proxyPass = "https://downloads.openwrt.org/releases/";
              extraConfig = ''
                ${lib.concatStringsSep "\n" (map (addr: "allow ${addr};") cfg.packageServer.proxyOpenWrtFeedAllowedAddrs)}
                ${lib.concatStringsSep "\n" (map (addr: "deny ${addr};") cfg.packageServer.proxyOpenWrtFeedDeniedAddrs)}
              '';
            };
            locations."= /modules".return = "301 /modules/";
            locations."/modules/" = {
              alias = "${config.users.users.firmware.home}/packages/";
              extraConfig = ''
                autoindex on;
              '';
            };
            addSSL = cfg.packageServer.enableSSL;
            useACMEHost = cfg.packageServer.useACMEHost;
          };
        })
      ];
    };

    users.users.firmware = {
      home = "/srv/firmware";
      openssh.authorizedKeys.keys = cfg.uploadUserAuthorizedKeys;
      isNormalUser = true;
      homeMode = "755";
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 80 443 ];
  };
}