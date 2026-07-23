{ pkgs, ... }:
{
  # Extend the isolated PVE LAN to the VMware-based builder over the existing
  # 192.168.2.0/24 management network.  The builder keeps that network solely
  # for tunnel transport and recovery; its service address lives on br-lan.
  systemd.network.netdevs = {
    br-lan = {
      netdevConfig = {
        Kind = "bridge";
        Name = "br-lan";
      };
    };

    gt-builder = {
      netdevConfig = {
        Kind = "gretap";
        Name = "gt-builder";
      };
      tunnelConfig = {
        Local = "192.168.2.5";
        Remote = "192.168.2.50";
      };
    };
  };

  systemd.network.networks = {
    # WAN: static IPv4 on OpenWrt LAN + DHCPv6-PD for IPv6 prefix
    eth0 = {
      matchConfig.Name = "eth0";
      address = [ "192.168.2.5/24" ];
      gateway = [ "192.168.2.2" ];
      networkConfig = {
        IPv6AcceptRA = "yes";
        DHCP = "ipv6";
        Tunnel = "gt-builder";
      };
      dhcpV6Config = {
        UseDelegatedPrefix = "yes";
        WithoutRA = "solicit";
      };
    };

    # LAN bridge: local PVE VMs and the builder GRETAP endpoint.
    eth1 = {
      matchConfig.Name = "eth1";
      networkConfig.Bridge = "br-lan";
      linkConfig.RequiredForOnline = "enslaved";
    };

    gt-builder = {
      matchConfig.Name = "gt-builder";
      networkConfig.Bridge = "br-lan";
    };

    # Static gateway for the bridged LAN, with IPv6 RA for local guests.
    br-lan = {
      matchConfig.Name = "br-lan";
      address = [
        "192.168.0.1/24"
        "192.168.0.4/24"
        "192.168.2.6/32"
        "240e:390:2568:fa81::1/64"
        "fc00:192:168:0::1/64"
      ];
      routes = [
        {
          Destination = "192.168.2.93/32";
          PreferredSource = "192.168.2.6";
          Scope = "link";
        }
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
