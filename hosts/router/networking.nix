{
  config,
  inputs,
  pkgs,
  ...
}:
{
  sops.secrets.pppoe-credentials = {
    sopsFile = inputs.secrets + "/per-host/pppoe/router.yaml";
    mode = "0400";
    restartUnits = [ "pppd-wan.service" ];
  };

  # Keep the WAN identity used by OpenWrt. Some ISPs bind the active PPPoE
  # session to the CPE MAC address.
  systemd.network.links."10-router-wan" = {
    matchConfig.OriginalName = "eth0";
    linkConfig.MACAddress = "02:c8:90:df:19:eb";
  };

  services.pppd = {
    enable = true;
    peers.wan.config = ''
      plugin pppoe.so
      nic-eth0
      ifname ppp0
      linkname wan
      ipparam wan
      file ${config.sops.secrets.pppoe-credentials.path}

      noauth
      noipdefault
      ipcp-accept-local
      ipcp-accept-remote
      persist
      maxfail 0
      holdoff 5
      hide-password

      defaultroute
      replacedefaultroute
      usepeerdns
      mtu 1492
      mru 1492

      lcp-echo-interval 10
      lcp-echo-failure 5
      lcp-echo-adaptive

      +ipv6
      ipv6cp-use-persistent
    '';
  };

  systemd.services.pppd-wan = {
    after = [
      "sops-install-secrets.service"
      "systemd-networkd.service"
      "sys-subsystem-net-devices-eth0.device"
    ];
    requires = [
      "sops-install-secrets.service"
      "sys-subsystem-net-devices-eth0.device"
    ];
  };

  systemd.network.netdevs.br-lan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-lan";
    };
  };

  systemd.network.networks = {
    # Physical WAN. PPPoE owns addressing and the default route.
    eth0 = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = "no";
        LinkLocalAddressing = "no";
      };
      linkConfig.RequiredForOnline = "carrier";
    };

    # PPPoE WAN. IPv4 is negotiated by pppd; networkd requests the ISP's
    # delegated IPv6 prefix and redistributes one /64 to br-lan.
    ppp0 = {
      matchConfig.Name = "ppp0";
      networkConfig = {
        DHCP = "ipv6";
        IPv6AcceptRA = "yes";
      };
      ipv6AcceptRAConfig = {
        DHCPv6Client = "always";
        UseDNS = false;
      };
      dhcpV6Config = {
        PrefixDelegationHint = "::/60";
        WithoutRA = "solicit";
      };
      linkConfig.RequiredForOnline = "routable";
    };

    # LAN bridge: local PVE VMs and physical clients.
    eth1 = {
      matchConfig.Name = "eth1";
      networkConfig.Bridge = "br-lan";
      linkConfig.RequiredForOnline = "enslaved";
    };

    # Static IPv4 gateway plus ULA and delegated IPv6 prefixes for LAN guests.
    br-lan = {
      matchConfig.Name = "br-lan";
      address = [
        "192.168.0.1/24"
        "192.168.0.4/24"
        "fc00:192:168::1/64"
      ];
      linkConfig.MTUBytes = "9000";
      networkConfig = {
        DHCPPrefixDelegation = true;
        IPv6AcceptRA = false;
        IPv6SendRA = true;
      };
      dhcpPrefixDelegationConfig = {
        UplinkInterface = "ppp0";
        SubnetId = "1";
        Announce = true;
        Assign = true;
        Token = "::1";
      };
      ipv6SendRAConfig = {
        EmitDNS = true;
        DNS = "fc00:192:168::1";
        Managed = false;
        OtherInformation = false;
      };
      ipv6Prefixes = [ { Prefix = "fc00:192:168::/64"; } ];
    };
  };

  # Trigger DDNS update when WAN becomes routable
  services.networkd-dispatcher = {
    enable = true;
    rules.trigger-ddns = {
      onState = [ "routable" ];
      script = ''
        #!${pkgs.runtimeShell}
        if [ "$IFACE" = "ppp0" ]; then
          echo "Restarting GCore DDNS ..."
          systemctl restart --no-block ddns-gcore.service
        fi
        exit 0
      '';
    };
  };
}
