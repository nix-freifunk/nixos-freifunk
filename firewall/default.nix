{ pkgs, lib, config, ... }:
{

  networking.firewall.extraInputRules = "jump input_extra";

  networking.firewall.filterForward = false;

  networking.firewall.extraForwardRules = ''
    counter
    # log prefix "[nftables] forward: " flags all
    jump forward_extra
  '';

  networking.nftables.tables.nixos-fw = {
    content = ''
      chain input_extra {}
      chain forward_extra {}

    ${lib.optionalString (!config.networking.firewall.filterForward) ''
    chain forward {
      type filter hook forward priority filter; policy drop;

      jump forward-allow
    }

    chain forward-allow {
      icmpv6 type != { router-renumbering, 139 } accept comment "Accept all ICMPv6 messages except renumbering and node information queries (type 139).  See RFC 4890, section 4.3."
      ${config.networking.firewall.extraForwardRules}
    }

    ''}'';
    family = "inet";
  };

  networking.nftables.tables.mangle = {
    content = ''
      chain forward_extra {}

      chain forward {
        type filter hook forward priority mangle; policy accept;
        jump forward_extra
      }
    '';
    family = "inet";
  };
}
