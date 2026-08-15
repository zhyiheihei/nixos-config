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
    matchConfig.OriginalName = "eth1";
    linkConfig.MACAddress = "02:c8:90:df:19:eb";
  };

  # r8125 cannot read the on-board EEPROM MAC at probe time, so both ports
  # start with a temporary address.  eth1 is pinned above for PPPoE; pin eth0
  # to its factory permanent address as well so the LAN bridge identity does
  # not depend on udev's machine-id derived persistent policy.
  systemd.network.links."10-router-lan" = {
    matchConfig.OriginalName = "eth0";
    linkConfig.MACAddress = "36:57:34:66:a7:af";
  };

  # Disable EEE on both RTL8125B ports: the PHY firmware (rtl8125b-2_0.0.2)
  # fails to wake from EEE low-power idle, causing intermittent carrier loss.
  # The NixOS linkConfig type does not expose EEE, so use ethtool directly.
  systemd.services.disable-eee = {
    description = "Disable EEE on RTL8125B NICs";
    wantedBy = [ "multi-user.target" ];
    after = [
      "sys-subsystem-net-devices-eth0.device"
      "sys-subsystem-net-devices-eth1.device"
    ];
    wants = [
      "sys-subsystem-net-devices-eth0.device"
      "sys-subsystem-net-devices-eth1.device"
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "-${pkgs.ethtool}/bin/ethtool --set-eee eth0 eee off"
        "-${pkgs.ethtool}/bin/ethtool --set-eee eth1 eee off"
      ];
    };
  };

  services.pppd = {
    enable = true;
    peers.wan.config = ''
      plugin pppoe.so
      nic-eth1
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
      "sys-subsystem-net-devices-eth1.device"
    ];
    requires = [
      "sops-install-secrets.service"
      "sys-subsystem-net-devices-eth1.device"
    ];
    serviceConfig = {
      Environment = "HOME=/run/pppd";
      RuntimeDirectory = "pppd";
      SuccessExitStatus = 5;
    };
  };

  systemd.network.netdevs.br-lan = {
    netdevConfig = {
      Kind = "bridge";
      Name = "br-lan";
    };
  };

  systemd.network.networks = {
    # Physical WAN. PPPoE owns addressing and the default route.
    eth1 = {
      matchConfig.Name = "eth1";
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = "no";
        LinkLocalAddressing = "no";
      };
      linkConfig.RequiredForOnline = "carrier";
    };

    # PPPoE WAN. IPv4 is negotiated by pppd; networkd requests the ISP's
    # delegated IPv6 prefix and redistributes one /64 to br-lan. CAKE shapes
    # the uplink (author's lt-home-router recipe: dual-src-host, NAT,
    # diffserv8) at the ~1G line rate measured in docs/research/11.
    ppp0 = {
      matchConfig.Name = "ppp0";
      networkConfig = {
        DHCP = "ipv6";
        IPv6AcceptRA = "yes";
        # pppd owns the PPPoE IPv4 address and default route; without this,
        # systemd-networkd can drop them when it applies ppp0.network after
        # IPCP completes, leaving the WAN with IPv6 only.
        KeepConfiguration = "static";
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
      cakeConfig = {
        Bandwidth = "1G";
        FlowIsolationMode = "dual-src-host";
        NAT = true;
        PriorityQueueingPreset = "diffserv8";
      };
    };

    # LAN bridge: local PVE VMs and physical clients.
    eth0 = {
      matchConfig.Name = "eth0";
      networkConfig.Bridge = "br-lan";
      linkConfig.RequiredForOnline = "enslaved";
    };

    # Static IPv4 gateway plus ULA and delegated IPv6 prefixes for LAN guests.
    br-lan = {
      matchConfig.Name = "br-lan";
      address = [
        "192.168.0.1/24"
        "fc00:192:168::1/64"
      ];
      linkConfig = {
        MTUBytes = "9000";
        RequiredForOnline = "routable";
      };
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
