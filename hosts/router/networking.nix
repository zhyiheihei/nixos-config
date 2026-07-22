{ pkgs, ... }:
{
  systemd.network.networks = {
    # WAN: static IPv4 on OpenWrt LAN + DHCPv6-PD for IPv6 prefix
    eth0 = {
      matchConfig.Name = "eth0";
      address = [ "192.168.2.5/24" ];
      gateway = [ "192.168.2.2" ];
      networkConfig = {
        IPv6AcceptRA = "yes";
        DHCP = "ipv6";
      };
      dhcpV6Config = {
        UseDelegatedPrefix = "yes";
        WithoutRA = "solicit";
      };
    };

    # LAN: static gateway for VMs, IPv6 RA with GUA + ULA
    eth1 = {
      matchConfig.Name = "eth1";
      address = [
        "192.168.0.1/24"
        "240e:390:2568:fa81::1/64"
        "fc00:192:168:0::1/64"
      ];
      linkConfig.MTUBytes = "9000";
      networkConfig.IPv6SendRA = "yes";
      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = "240e:390:2568:fa81::1";
        Managed = true;
        OtherInformation = true;
      };
      ipv6Prefixes = [
        { Prefix = "240e:390:2568:fa81::/64"; }
        { Prefix = "fc00:192:168:0::/64"; }
      ];
    };
  };

  # Trigger DDNS update when WAN becomes routable
  services.networkd-dispatcher = {
    enable = true;
    rules.trigger-ddns = {
      onState = [ "routable" ];
      script = ''
        #!${pkgs.runtimeShell}
        if [ "$IFACE" = "eth0" ]; then
          echo "Restarting GCore DDNS ..."
          systemctl restart --no-block ddns-gcore.service
        fi
        exit 0
      '';
    };
  };
}
