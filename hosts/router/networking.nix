{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  tc = "${pkgs.iproute2}/bin/tc";
  queueCount = LT.this.cpuThreads;
  flowEntriesPerQueue = 8192;
  # Both RTL8125 ports have queueCount RX queues, so the global RPS table
  # must cover 2 * queueCount queues.
  rpsFlowEntries = 2 * queueCount * flowEntriesPerQueue;

  rpsScript = pkgs.writeShellScript "router-rps" ''
    set -eu

    # Keep mq plus one fq_codel per hardware TX queue; replacing the root
    # with a single fq_codel collapses the two RTL8125 TX queues.
    if ! ${tc} qdisc show dev eth0 2>/dev/null | grep -q 'qdisc fq_codel.*parent'; then
      ${tc} qdisc replace dev eth0 root mq 2>/dev/null || true
      handle=$(${tc} qdisc show dev eth0 | awk '$1 == "qdisc" && $2 == "mq" { print $3; exit }')
      if [ -n "$handle" ]; then
        ${tc} qdisc replace dev eth0 parent "''${handle}1" fq_codel
        ${tc} qdisc replace dev eth0 parent "''${handle}2" fq_codel
      fi
    fi

    # One RX queue per core: the r8125 driver exposes eth0-0..3 / eth1-0..3
    # MSI-X vectors, but irqbalance packs several of them onto one CPU and
    # that caused NIC rx_missed/retransmits under multi-flow load.  Pin each
    # queue IRQ to its matching CPU instead and disable irqbalance below.
    for dev in eth0 eth1; do
      for q in $(seq 0 $(( ${toString queueCount} - 1 ))); do
        irq=$(
          awk -v dev="$dev" -v q="$q" \
            '$NF == dev "-" q { sub(":", "", $1); print $1 }' \
            /proc/interrupts | head -1
        )
        if [ -n "$irq" ]; then
          echo "$q" > "/proc/irq/$irq/smp_affinity_list"
        fi
      done
    done

    for dev in eth0 eth1; do
      for q in /sys/class/net/$dev/queues/rx-*; do
        if [ -e "$q/rps_cpus" ]; then
          echo f > "$q/rps_cpus"
          echo ${toString flowEntriesPerQueue} > "$q/rps_flow_cnt"
        fi
      done
      for q in /sys/class/net/$dev/queues/tx-*; do
        if [ -e "$q/xps_cpus" ]; then
          echo f > "$q/xps_cpus"
        fi
      done
    done
  '';
in
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
    # diffserv8) at the ~1G line rate measured in docs/human/research/11-network-acceptance-2026-08-12.md.
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

  ########################################
  # WLAN (hostapd AP)
  ########################################

  # MediaTek MT7921 is the preferred radio for this router: unlike the Intel
  # 7265 it supports 802.11ax, and its upstream mt76 driver is a better fit for
  # AP mode than the RTL8852BE rtw89 driver.
  boot.kernelModules = [
    "mt7921e"
    "mt7921_common"
  ];
  hardware.wirelessRegulatoryDatabase = true;
  environment.systemPackages = [ pkgs.iw ];

  sops.secrets.router-wifi-password = {
    sopsFile = inputs.secrets + "/per-host/wifi/router.yaml";
    key = "wifi-password";
    mode = "0400";
    restartUnits = [ "hostapd.service" ];
  };

  services.hostapd = {
    enable = true;
    radios.wlan0 = {
      band = "5g";
      channel = 36;
      countryCode = "CN";
      wifi4.capabilities = [
        "HT40+"
        "SHORT-GI-20"
        "SHORT-GI-40"
      ];
      wifi5 = {
        enable = true;
        operatingChannelWidth = "80";
      };
      wifi6 = {
        enable = true;
        operatingChannelWidth = "80";
      };
      settings = {
        # Channel 36 belongs to the 80 MHz block centred on channel 42.
        vht_oper_centr_freq_seg0_idx = 42;
        he_oper_centr_freq_seg0_idx = 42;
      };
      networks.wlan0 = {
        ssid = "moli-rk-wifi";
        authentication = {
          mode = "wpa3-sae-transition";
          wpaPasswordFile = config.sops.secrets.router-wifi-password.path;
          saePasswords = [
            { passwordFile = config.sops.secrets.router-wifi-password.path; }
          ];
        };
        settings.bridge = "br-lan";
      };
    };
  };

  # hostapd changes wlan0 from managed to AP mode before adding it to br-lan.
  # systemd-networkd must not try to enslave the still-managed interface first.
  # Kea, CoreDNS, IPv6 RA and the firewall already operate on br-lan.

  ########################################
  # NIC queue / RPS tuning (RTL8125)
  ########################################

  # Follow the OpenWrt NanoPi R5C high-throughput recipe that is backed by
  # community measurements: raise device/socket buffers and spread every RX
  # queue across all four cores.  The r8125 override opens 4 RX queues;
  # the RPS flow tables are sized for both NICs.  BBR is already enabled
  # globally by nixos/minimal-components/networking.nix.  NAPI and qdisc
  # values are backed by A/B medians in docs/human/research/10-router-rx-queue-4.md.
  boot.kernel.sysctl = {
    "net.core.netdev_budget" = 1200;
    "net.core.netdev_budget_usecs" = 30000;
    "net.core.flow_limit_table_len" = 16384;
    "net.core.netdev_max_backlog" = 5000;
    "net.core.optmem_max" = 131072;
    "net.core.rmem_max" = 16777216;
    "net.core.wmem_max" = 16777216;
    "net.core.rps_sock_flow_entries" = rpsFlowEntries;
  };

  # The public default enables irqbalance on multi-core hosts, but its queue
  # placement hurt RTL8125 multi-queue performance on this board.  Keep the
  # network IRQs pinned by router-rps instead.
  services.irqbalance.enable = lib.mkForce false;

  systemd.services.router-rps = {
    description = "Reassert RTL8125 queue tuning, IRQ affinity and fq_codel";
    wantedBy = [ "multi-user.target" ];
    after = [
      "systemd-networkd.service"
      "sys-subsystem-net-devices-eth0.device"
      "sys-subsystem-net-devices-eth1.device"
    ];
    wants = [
      "sys-subsystem-net-devices-eth0.device"
      "sys-subsystem-net-devices-eth1.device"
    ];
    path = [
      pkgs.coreutils
      pkgs.gawk
      pkgs.iproute2
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = rpsScript;
      Restart = "on-failure";
      RestartSec = "5";
    };
  };

  # r8125 driver resets or link reinit can wipe qdisc/affinity/RPS settings
  # while systemd still reports the oneshot active; reassert every minute.
  systemd.timers.router-rps-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/1";
      Unit = "router-rps.service";
      Persistent = false;
    };
  };
}
