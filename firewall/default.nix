{ pkgs, lib, config, ... }:
{

  networking.firewall.extraInputRules = "jump input_extra";

  networking.firewall.filterForward = true;
  networking.firewall.extraForwardRules = ''
    counter
    # log prefix "[nftables] forward: " flags all
    jump forward_extra
  '';

  networking.nftables.tables.nixos-fw = {
    content = ''
      chain input_extra {}
      chain forward_extra {}
    '';
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