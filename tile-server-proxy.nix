{ config, pkgs, lib, ...}:
with lib;

let
  cfg = config.services.freifunk.tile-server-proxy;

in
{
  options.services.freifunk.tile-server-proxy = {
    enable = mkEnableOption "Enable Bird";

    domain = mkOption {
      type = types.str;
      example = "tiles.example.com";
      description = "The domain to serve the tile server on";
    };

    enableSSL = mkOption {
      type = types.bool;
      default = false;
      description = "Enable SSL for the meshviewer vhost";
    };

    useACMEHost = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "The host to use for ACME";
    };

    abuseContactMail = mkOption {
      type = types.str;
      example = "mail@example.org";
      description = "The contact mail for the tile server";
    };

    openFirewall = mkOption {
      type = types.bool;
      default = false;
      description = "Open the firewall for the HTTP and HTTPS ports";
    };
  };

  config = mkIf cfg.enable {
    services.nginx = {
      enable = lib.mkDefault true;
      resolver.addresses = [
        "1.1.1.1"
        "[2606:4700:4700::1001]"
      ];
      resolver.valid = "30s";
      upstreams = {
        "osmtiles" = {
          servers = {
            "a.tile.openstreetmap.org" = {};
            "b.tile.openstreetmap.org" = {};
            "c.tile.openstreetmap.org" = {};
          };
          extraConfig = ''
            keepalive 16;
          '';

        };
        lighttiles = {
          servers = {
            "cartodb-basemaps-a.global.ssl.fastly.net" = {};
            "cartodb-basemaps-b.global.ssl.fastly.net" = {};
            "cartodb-basemaps-c.global.ssl.fastly.net" = {};
          };
          extraConfig = ''
            keepalive 16;
          '';
        };
      };

      proxyCachePath."osmtilecache" = {
        enable = true;
        levels = "1:2";
        inactive = "14d";
        keysZoneName = "osmtilecache";
        keysZoneSize = "64m";
        maxSize = "4096M";
      };

      proxyCachePath."lighttilecache" = {
        enable = true;
        levels = "1:2";
        inactive = "14d";
        keysZoneName = "lighttilecache";
        keysZoneSize = "64m";
        maxSize = "4096M";
      };

      virtualHosts."${cfg.domain}" = {
        locations."/".tryFiles = "$uri @osm";
        locations."/light_all/".tryFiles = "$uri @light_all";

        # locations."/".root = "${meshviewerPkg}";
        # locations."/".extraConfig = ''
        #   try_files $uri $uri/ =404;
        # '';

        locations."@osm" = {
          proxyPass = "http://osmtiles";

          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Accept-Encoding "";
            proxy_set_header User-Agent "Mozilla/5.0 (compatible; OSMTileCache/1.0; +mailto:${cfg.abuseContactMail}; +http://${cfg.domain}/)";
            proxy_set_header Host tile.openstreetmap.org;
            add_header X-Cache-Status $upstream_cache_status;
            add_header X-Cache-Upstream-Status $upstream_http_x_cache_status;
            proxy_cache osmtilecache;
            proxy_store off;
            proxy_cache_key $uri$is_args$args;
            proxy_cache_valid 200 301 302 14d;
            proxy_cache_valid 404 1m;
            proxy_cache_valid any 1m;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
            proxy_cache_use_stale error timeout updating invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
            proxy_hide_header Via;
            proxy_hide_header X-Cache;
            proxy_hide_header X-Cache-Lookup;
            proxy_hide_header X-Cache-Status;
            proxy_hide_header Strict-Transport-Security;
            proxy_hide_header Set-Cookie;
            proxy_ignore_headers Set-Cookie;
            proxy_ignore_headers X-Accel-Expires Expires Cache-Control;
            expires 14d;
          '';
        };

        locations."@light_all" = {
          proxyPass = "http://lighttiles";

          extraConfig = ''
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            proxy_set_header Accept-Encoding "";
            proxy_set_header User-Agent "Mozilla/5.0 (compatible; OSMTileCache/1.0; +mailto:${cfg.abuseContactMail}; +http://${cfg.domain}/)";
            proxy_set_header Host cartodb-basemaps-a.global.ssl.fastly.net;
            add_header X-Cache-Status $upstream_cache_status;
            add_header X-Cache-Upstream-Status $upstream_http_x_cache_status;
            proxy_cache lighttilecache;
            proxy_store off;
            proxy_cache_key $uri$is_args$args;
            proxy_cache_valid 200 301 302 14d;
            proxy_cache_valid 404 1m;
            proxy_cache_valid any 1m;
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
            proxy_cache_use_stale error timeout updating invalid_header http_500 http_502 http_503 http_504 http_403 http_404;
            proxy_hide_header Via;
            proxy_hide_header X-Cache;
            proxy_hide_header X-Cache-Lookup;
            proxy_hide_header X-Cache-Status;
            proxy_hide_header Strict-Transport-Security;
            proxy_hide_header Set-Cookie;
            proxy_ignore_headers Set-Cookie;
            proxy_ignore_headers X-Accel-Expires Expires Cache-Control;
            expires 14d;
          '';
        };

        forceSSL = cfg.enableSSL;
        useACMEHost = cfg.useACMEHost;
      };
    };

    networking.firewall.allowedTCPPorts = mkIf cfg.openFirewall [ 80 443 ];
  };
}