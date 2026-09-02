{
  LT,
  lib,
  config,
  pkgs,
  ...
}:
let
  edgeAddress = LT.hosts.rock5c.interconnect.IPv4;

  # nftables.service loads the main ruleset before network interfaces exist,
  # and the flowtable needs real netdevs.  Upstream NixOS issue #141802
  # endorses adding flow offload with a separate service after interfaces are
  # up; its failure is non-critical.  Requires the new kernel with
  # NF_FLOW_TABLE support after a staged boot.  Only WAN (ppp0) flows are
  # offloaded; hairpin flows stay on the normal netfilter path because the
  # measured retransmit benefit is documented in docs/human/research/10-router-rx-queue-4.md.
  # Note that offloaded flows bypass the rest of FILTER_FORWARD, so policy
  # that can change after the first packet must live in pre-forward hooks.
  nft = "${lib.getExe' pkgs.nftables "nft"}";
  flowtableScript = pkgs.writeShellScript "router-flowtable" ''
    set -eu

    wan_rule='ct state { established, related } iifname "ppp0" flow add @f'
    lan_rule='ct state { established, related } iifname "br-lan" oifname "ppp0" flow add @f'

    delete_flow_rules() {
      filter=$1
      handles=$(
        ${nft} -a list chain inet lantian FILTER_FORWARD |
          grep 'flow add @f' |
          grep "$filter" |
          sed -n 's/.*# handle \([0-9][0-9]*\).*/\1/p' || true
      )
      for handle in $handles; do
        ${nft} delete rule inet lantian FILTER_FORWARD handle "$handle"
      done
    }

    ensure_flow_rule() {
      pattern=$1
      rule=$2
      if ! ${nft} list chain inet lantian FILTER_FORWARD | grep -Fq "$pattern"; then
        ${nft} insert rule inet lantian FILTER_FORWARD $rule comment "router-flowtable"
      fi
    }

    i=0
    while [ ! -e /sys/class/net/br-lan ] || [ ! -e /sys/class/net/ppp0 ]; do
      sleep 1
      i=$((i + 1))
      if [ "$i" -ge 120 ]; then
        echo "router-flowtable: br-lan/ppp0 not up after 120s" >&2
        exit 1
      fi
    done

    rebuild=0
    if ! ${nft} list flowtable inet lantian f >/dev/null 2>&1; then
      rebuild=1
    elif ! ${nft} list flowtable inet lantian f | grep -q ppp0; then
      # PPPoE redial recreates ppp0; a stale flowtable binding must be rebuilt.
      rebuild=1
    fi

    if [ "$rebuild" -eq 1 ]; then
      delete_flow_rules 'flow add @f'
      if ${nft} list flowtable inet lantian f >/dev/null 2>&1; then
        ${nft} delete flowtable inet lantian f
      fi
      ${nft} -f /etc/nftables/flowtable.nft
      ensure_flow_rule 'iifname "ppp0" flow add @f' "$wan_rule"
      ensure_flow_rule 'iifname "br-lan" oifname "ppp0" flow add @f' "$lan_rule"
    else
      # One-time migration: drop unowned flow-add rules, then reassert ours.
      unowned=$(
        ${nft} -a list chain inet lantian FILTER_FORWARD |
          grep 'flow add @f' |
          grep -v 'router-flowtable' |
          sed -n 's/.*# handle \([0-9][0-9]*\).*/\1/p' || true
      )
      for handle in $unowned; do
        ${nft} delete rule inet lantian FILTER_FORWARD handle "$handle"
      done
      delete_flow_rules 'router-flowtable'
      ensure_flow_rule 'iifname "ppp0" flow add @f' "$wan_rule"
      ensure_flow_rule 'iifname "br-lan" oifname "ppp0" flow add @f' "$lan_rule"
    fi
  '';


  ipv4Set = name: value: ''
    set ${name} {
      type ipv4_addr
      flags constant, interval
      elements = { ${builtins.concatStringsSep ", " value} }
    }
  '';

  ipv6Set = name: value: ''
    set ${name} {
      type ipv6_addr
      flags constant, interval
      elements = { ${builtins.concatStringsSep ", " value} }
    }
  '';

  publicFirewalledPorts = [
    # Samba
    137
    138
    139
    445
    LT.port.CUPS
    LT.port.Rsync
    LT.port.NMEA
    LT.port.mDNS
    LT.port.qBitTorrent.WebUI
    LT.port.qBitTorrentPT.WebUI
    LT.port.qBitTorrentSeedbox.WebUI
  ];
in
{
  networking.nftables.tables.lantian.content = lib.mkForce ''
    chain FILTER_INPUT {
      # Author's policy-accept recipe (lt-home-router): only explicit drops,
      # WAN ingress goes through PUBLIC_INPUT for the never-exposed ports.
      type filter hook input priority 5; policy accept;

      # Drop timestamp ICMP pkts
      meta l4proto icmp icmp type timestamp-reply drop
      meta l4proto icmp icmp type timestamp-request drop

      # Block Avahi multicast DNS on ZeroTier.
      iifname "zt*" udp sport 5353 reject
      iifname "zt*" udp dport 5353 reject

      iifname "ppp0" jump PUBLIC_INPUT
    }

    chain FILTER_FORWARD {
      type filter hook forward priority 5; policy accept;

      # Clamp TCP MSS
      tcp flags syn tcp option maxseg size set rt mtu

      # Allow existing connections
      ct state { established, related } accept

      # Allow DNATed connections
      ct status dnat accept

      # Block forwarding from public interface
      iifname "ppp0" drop
    }

    chain FILTER_OUTPUT {
      type filter hook output priority 5; policy accept;

      # Block Avahi multicast DNS on ZeroTier.
      oifname "zt*" udp sport 5353 reject
      oifname "zt*" udp dport 5353 reject

      # Block mDNS on WAN
      fib saddr type local oifname "ppp0" jump PUBLIC_OUTPUT
    }

    chain NAT_PREROUTING {
      type nat hook prerouting priority -95; policy accept;

      # Public services: direct PPPoE WAN → greencloud.
      fib daddr type local tcp dport { 80, 443, 2222 } iifname "ppp0" dnat ip to ${edgeAddress}
      fib daddr type local udp dport 443 iifname "ppp0" dnat ip to ${edgeAddress}
      fib daddr type local tcp dport { 80, 443, 2222 } iifname "ppp0" dnat ip6 to [fc00:192:168::10]
      fib daddr type local udp dport 443 iifname "ppp0" dnat ip6 to [fc00:192:168::10]

      # Compatibility endpoints previously forwarded by OpenWrt.
      # VaultS3 is a bulk data path and terminates directly on OPI5P/NVMe.
      fib daddr type local tcp dport 8443 iifname "ppp0" dnat ip to ${LT.hosts.opi5p.interconnect.IPv4}:8443
      fib daddr type local tcp dport 4000 iifname "ppp0" dnat ip to ${edgeAddress}:443

      # Redirect LAN DNS requests to the isolated CoreDNS client namespace.
      # br-lan is the bridge ingress seen by LAN guests; eth0 covers direct
      # physical traffic.
      fib daddr type local tcp dport ${LT.portStr.DNS} iifname { "br-lan", "eth0" } dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}
      fib daddr type local tcp dport ${LT.portStr.DNS} iifname { "br-lan", "eth0" } dnat ip6 to [${config.lantian.netns.coredns-client.ipv6}]:${LT.portStr.DNS}
      fib daddr type local udp dport ${LT.portStr.DNS} iifname { "br-lan", "eth0" } dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}
      fib daddr type local udp dport ${LT.portStr.DNS} iifname { "br-lan", "eth0" } dnat ip6 to [${config.lantian.netns.coredns-client.ipv6}]:${LT.portStr.DNS}

      # Hairpin NAT follows the author's router layout: LAN clients keep using
      # public DNS, while traffic is returned to the actual home service host.
      # VaultS3 is the one bulk endpoint owned by OPI5P rather than ROCK 5C.
      fib daddr type local tcp dport 8443 iifname { "br-lan", "eth0" } ip daddr != @RESERVED_IPV4 dnat ip to ${LT.hosts.opi5p.interconnect.IPv4}:8443

      # All remaining public services are handled by the ROCK 5C edge.
      fib daddr type local iifname "br-lan" ip daddr != @RESERVED_IPV4 dnat ip to ${edgeAddress}
      fib daddr type local iifname "br-lan" ip6 daddr != @RESERVED_IPV6 dnat ip6 to [fc00:192:168::10]
    }

    chain NAT_INPUT {
      type nat hook input priority 105; policy accept;
    }

    chain NAT_OUTPUT {
      type nat hook output priority -95; policy accept;
    }

    chain NAT_POSTROUTING {
      type nat hook postrouting priority 105; policy accept;

      # Masquerade traffic leaving the LAN, including WAN and overlay networks.
      meta nfproto ipv4 oifname != "br-lan" masquerade

      # Masquerade DNATed (hairpin) traffic so return path goes through router
      meta nfproto ipv4 oifname "br-lan" ct status dnat masquerade

    }

    set PUBLIC_FIREWALLED_PORTS {
      type inet_service
      flags constant
      elements = {
        ${lib.concatMapStringsSep "," builtins.toString publicFirewalledPorts}
      }
    }

    chain PUBLIC_INPUT {
      tcp dport @PUBLIC_FIREWALLED_PORTS reject with tcp reset
      udp dport @PUBLIC_FIREWALLED_PORTS reject with icmpx type port-unreachable
      return
    }

    chain PUBLIC_OUTPUT {
      tcp sport @PUBLIC_FIREWALLED_PORTS drop
      udp sport @PUBLIC_FIREWALLED_PORTS drop
      return
    }

    # IP Sets
    ${ipv4Set "RESERVED_IPV4" LT.constants.reserved.IPv4}
    ${ipv6Set "RESERVED_IPV6" LT.constants.reserved.IPv6}
  '';

  environment.etc."nftables/flowtable.nft".text = ''
    add flowtable inet lantian f {
      hook ingress priority filter
      devices = { ppp0, br-lan }
    }
  '';

  systemd.services.router-flowtable = {
    description = "Enable nftables flowtable fast path after interfaces are up";
    wantedBy = [ "multi-user.target" ];
    after = [
      "nftables.service"
      "systemd-networkd.service"
      "pppd-wan.service"
    ];
    wants = [ "nftables.service" ];
    # nftables restarts flush the table; the periodic check service restores
    # the fast path within a minute, and restarting with pppd-wan covers
    # PPPoE redial.
    partOf = [
      "nftables.service"
      "pppd-wan.service"
    ];
    path = [
      pkgs.gnugrep
      pkgs.gnused
    ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = flowtableScript;
      TimeoutStartSec = "150";
      Restart = "on-failure";
      RestartSec = "5";
    };
  };

  # nftables reloads flush the table and PPPoE redials recreate ppp0; the
  # idempotent script re-adds the flowtable and scoped forward rules on a
  # short timer.
  systemd.timers.router-flowtable-check = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*:0/1";
      Persistent = false;
    };
  };

  systemd.services.router-flowtable-check = {
    description = "Reassert nftables flowtable after reloads or PPPoE redial";
    after = [ "nftables.service" ];
    path = [
      pkgs.gnugrep
      pkgs.gnused
    ];
    serviceConfig = {
      Type = "oneshot";
      TimeoutStartSec = "150";
      ExecStart = flowtableScript;
    };
  };
}
