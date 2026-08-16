{
  LT,
  lib,
  config,
  ...
}:
let
  edgeAddress = LT.hosts.rock5c.interconnect.IPv4;

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
      type filter hook input priority 5; policy drop;

      # Drop invalid, accept established/related.
      ct state invalid drop
      ct state { established, related } accept

      # Drop timestamp ICMP pkts
      meta l4proto icmp icmp type timestamp-reply drop
      meta l4proto icmp icmp type timestamp-request drop

      # Block Avahi multicast DNS on ZeroTier.
      iifname "zt*" udp sport 5353 reject
      iifname "zt*" udp dport 5353 reject

      # Trusted local paths: loopback, LAN bridge (wlan0 is enslaved to it),
      # network namespaces (coredns-client), ZeroTier (management plane).
      iifname "lo" accept
      iifname { "br-lan", "eth0" } accept
      iifname "ns-*" accept
      iifname "zt*" accept

      # WAN input is drop-by-default (routing-layer-security-audit-2026-08-16
      # §3.1; deviation from the author's policy-accept recipe, same model as
      # hosts/h28k/firewall.nix).  Public service ports are DNATed in
      # PREROUTING to rock5c/opi5p and never reach this chain; the only
      # router-local listeners reachable from ppp0 are ICMP, the IPv6
      # link-local control plane (NDP/RA/DHCPv6) and the qBittorrent peer
      # port 31220 (the torrentingPort override in qbittorrent.nix).
      iifname "ppp0" jump PUBLIC_INPUT
      iifname "ppp0" meta l4proto icmp accept
      iifname "ppp0" meta l4proto ipv6-icmp accept
      iifname "ppp0" ip6 saddr fe80::/10 accept
      iifname "ppp0" tcp dport 31220 accept
      iifname "ppp0" udp dport 31220 accept
    }

    chain FILTER_FORWARD {
      type filter hook forward priority 5; policy accept;

      # Clamp TCP MSS
      tcp flags syn tcp option maxseg size set rt mtu

      # Allow existing connections
      ct state { established, related } accept

      # Anti-spoofing (audit §3.2): reserved/internal source addresses must
      # never be forwarded from the WAN, even when DNATed into LAN services.
      # Legit WAN peers carry public source addresses; established flows were
      # validated by conntrack above.
      iifname "ppp0" ip saddr @RESERVED_IPV4 drop
      iifname "ppp0" ip6 saddr @RESERVED_IPV6 drop

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
      fib daddr type local tcp dport 8443 iifname "ppp0" dnat ip to ${LT.hosts.opi5p.interconnect.IPv4}:443
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
      fib daddr type local tcp dport 8443 iifname { "br-lan", "eth0" } ip daddr != @RESERVED_IPV4 dnat ip to ${LT.hosts.opi5p.interconnect.IPv4}:443

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
      # Anti-spoofing (audit §3.2): reserved/internal sources must never
      # arrive on the WAN.  fe80::/10 is not part of @RESERVED_IPV6, so the
      # link-local accept in FILTER_INPUT still passes NDP/RA/DHCPv6.
      ip saddr @RESERVED_IPV4 drop
      ip6 saddr @RESERVED_IPV6 drop

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
}
