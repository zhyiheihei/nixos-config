{
  LT,
  lib,
  config,
  ...
}:
let
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
  ];
in
{
  networking.nftables.tables.lantian.content = lib.mkForce ''
    chain FILTER_INPUT {
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

      # Public services: direct PPPoE WAN → colocrossing.
      fib daddr type local tcp dport { 80, 443, 2222 } iifname "ppp0" dnat ip to 192.168.0.51
      fib daddr type local udp dport 443 iifname "ppp0" dnat ip to 192.168.0.51
      fib daddr type local tcp dport { 80, 443, 2222 } iifname "ppp0" dnat ip6 to [fc00:192:168::10]
      fib daddr type local udp dport 443 iifname "ppp0" dnat ip6 to [fc00:192:168::10]

      # Compatibility endpoints previously forwarded by OpenWrt.
      fib daddr type local tcp dport 8443 iifname "ppp0" dnat ip to 192.168.0.51:443
      fib daddr type local tcp dport 4000 iifname "ppp0" dnat ip to 192.168.0.51:443

      # Redirect LAN DNS requests to the isolated CoreDNS client namespace.
      # br-lan is the bridge ingress seen by LAN guests; eth1 covers direct
      # physical traffic.
      fib daddr type local tcp dport ${LT.portStr.DNS} iifname { "br-lan", "eth1" } dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}
      fib daddr type local tcp dport ${LT.portStr.DNS} iifname { "br-lan", "eth1" } dnat ip6 to [${config.lantian.netns.coredns-client.ipv6}]:${LT.portStr.DNS}
      fib daddr type local udp dport ${LT.portStr.DNS} iifname { "br-lan", "eth1" } dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}
      fib daddr type local udp dport ${LT.portStr.DNS} iifname { "br-lan", "eth1" } dnat ip6 to [${config.lantian.netns.coredns-client.ipv6}]:${LT.portStr.DNS}

      # Hairpin NAT: LAN accessing public IP gets redirected to colocrossing
      fib daddr type local iifname "br-lan" ip daddr != @RESERVED_IPV4 dnat ip to 192.168.0.51
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

      # Masquerade outbound to WAN
      meta nfproto ipv4 oifname "ppp0" masquerade

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
}
