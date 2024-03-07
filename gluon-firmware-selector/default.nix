{ config, lib, pkgs, ... }:
with lib;

let
  cfg = config.services.gluon-firmware-selector;

  pkg = pkgs.callPackage ./pkg.nix {};
  configFile = pkgs.writeText "config.js" cfg.config;

in

{

  options.services.gluon-firmware-selector = {
    enable = mkOption {
      type = types.bool;
      default = false;
    };

    config = mkOption {
      type = types.str;
      default = ''
        /*
        * This program is free software: you can redistribute it and/or modify
        * it under the terms of the GNU Affero General Public License as published by
        * the Free Software Foundation, either version 3 of the License, or
        * (at your option) any later version.
        *
        * This program is distributed in the hope that it will be useful,
        * but WITHOUT ANY WARRANTY; without even the implied warranty of
        * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
        * GNU Affero General Public License for more details.
        *
        * You should have received a copy of the GNU Affero General Public License
        * along with this program.  If not, see <http://www.gnu.org/licenses/>.
        */

        var config = {
          // list images on console that match no model
          listMissingImages: true,
          // see devices.js for different vendor model maps
          vendormodels: vendormodels,
          // set enabled categories of devices (see devices.js)
          enabled_device_categories: ["recommended"],
          // Display a checkbox that allows to display not recommended devices.
          // This only make sense if enabled_device_categories also contains not
          // recommended devices.
          recommended_toggle: false,
          // Optional link to an info page about no longer recommended devices
          recommended_info_link: null,
          // community prefix of the firmware images
          community_prefix: 'gluon-ffth-',
          // firmware version regex
          version_regex: '-([0-9]+.[0-9]+.[0-9x]+([+-~][0-9]+)?)[.-]',
          // relative image paths and branch
          directories: {
            './images/stable/factory/': 'stable',
            './images/stable/sysupgrade/': 'stable',
            './images/stable/other/': 'stable',
            './images/beta/factory/': 'beta',
            './images/beta/sysupgrade/': 'beta',
            './images/beta/other/': 'beta',
            './images/experimental/factory/': 'experimental',
            './images/experimental/sysupgrade/': 'experimental',
            './images/experimental/other/': 'experimental',
            './images/nightly/factory/': 'nightly',
            './images/nightly/sysupgrade/': 'nightly',
            './images/nightly/other/': 'nightly'
          },
          // page title
          title: 'Firmware',
          // branch descriptions shown during selection
          branch_descriptions: {
            stable: 'Gut getestet, zuverlässig und stabil.',
            beta: 'Vorabtests neuer Stable-Kandidaten.',
            experimental: 'Ungetestet, teilautomatisch generiert.',
            nightly: 'Absolut ungetestet, automatisch generiert. Nur für absolute Experten.'
          },
          // recommended branch will be marked during selection
          recommended_branch: 'stable',
          // experimental branches (show a warning for these branches)
          experimental_branches: ['experimental', 'nightly'],
          // path to preview pictures directory
          preview_pictures: 'pictures/',
          // link to changelog
          changelog: 'CHANGELOG.html',
          // links for instructions like flashing of certain devices (optional)
          // can be set for a whole model or individual revisions
          // overwrites default values from devices_info in devices.js
          // devices_info: {
          //   'AVM': {
          //     "FRITZ!Box 4040": "https://fritz-tools.readthedocs.io"
          //   },
          //   "TP-Link": {
          //     "TL-WR841N/ND": {"v13": "https://wiki.freifunk.net/TP-Link_WR841ND/Flash-Anleitung_v13"}
          //   }
          // }
        };
        '';
      description = "The config.";
    };

    package = mkOption {
      type = types.package;
      default = pkg;
      description = "The package to use";
    };

    nginx = {
      enable = mkOption {
        type = types.bool;
        default = true;
        description = "configure nginx virtual host";
      };
      hostName = mkOption {
        type = types.str;
        default = "firmware.example.org";
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
        locations."/".root = "${cfg.package}";
        locations."/".extraConfig = ''
          try_files $uri $uri/ =404;
        '';
        locations."=/config.js".alias = "${configFile}";
        locations."/images/" = {
          alias = "${config.users.users.firmware.home}/images/";
          extraConfig = ''
            autoindex on;
          '';
        };
        
      };
      virtualHosts."fw.gluon.ff.tomhe.de" = {
        locations."/" = {
          root = "${config.users.users.firmware.home}/images/";
          extraConfig = ''
            autoindex on;
          '';
        };
      };
      virtualHosts."opkg.ff.tomhe.de" = {
        locations."/".extraConfig = ''
          default_type text/html;
          return 200 "<!DOCTYPE html><h1>OPKG</h1><ul><li><a href=\"/modules/\">modules</a></li><li><a href=\"/openwrt/\">openwrt</a></li></ul>\n";
        '';
        locations."/openwrt/releases/" = {
          proxyPass = "https://downloads.openwrt.org/releases/";

        };
        locations."/modules/" = {
          alias = "${config.users.users.firmware.home}/packages/";
          extraConfig = ''
            autoindex on;
          '';
        };
      };
    };

    users.users.firmware = {
      home = "/srv/firmware";
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC6vdL+rfOsnP4AmUJhlF77fPFJg6dtnYSGbTCX+EtHk github-actions@github"
      ] ++ config.users.users.root.openssh.authorizedKeys.keys;
      isNormalUser = true;
      homeMode = "755";
    };

    networking.firewall.allowedTCPPorts = [ 80 ];
  };
}