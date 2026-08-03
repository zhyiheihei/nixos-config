{
  config,
  lib,
  LT,
  ...
}:
{
  # The repository-wide prefix classifier treats both eth0 and eth1 as WAN.
  # Override it for this two-port router so eth0 is trusted LAN and eth1 is an
  # untrusted DHCP uplink.
  networking.nftables.tables.lantian.content = lib.mkForce ''
    chain FILTER_INPUT {
      type filter hook input priority 5; policy drop;

      ct state invalid drop
      ct state { established, related } accept

      iifname "lo" accept
      iifname "eth0" accept
      iifname "ns-*" accept
      iifname "zt*" accept

      # DHCP replies and direct ZeroTier peer traffic on the uplink.
      iifname "eth1" udp sport 67 udp dport 68 accept
      iifname "eth1" udp dport 9993 accept

      meta l4proto icmp accept
      meta l4proto ipv6-icmp accept
    }

    chain FILTER_FORWARD {
      type filter hook forward priority 5; policy drop;

      tcp flags syn tcp option maxseg size set rt mtu
      ct state invalid drop
      ct state { established, related } accept
      ct status dnat accept

      # LAN and service namespaces may use the WAN. Once ZeroTier is enrolled,
      # LTNET may also route into the remote-site LAN without source NAT.
      iifname "eth0" accept
      iifname "ns-*" accept
      iifname "zt*" oifname "eth0" accept
    }

    chain FILTER_OUTPUT {
      type filter hook output priority 5; policy accept;
    }

    chain NAT_PREROUTING {
      type nat hook prerouting priority -95; policy accept;

      # CoreDNS runs in its client namespace; present it to LAN clients at the
      # router gateway address on both TCP and UDP port 53.
      fib daddr type local tcp dport ${LT.portStr.DNS} iifname "eth0" dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}
      fib daddr type local udp dport ${LT.portStr.DNS} iifname "eth0" dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}
    }

    chain NAT_INPUT {
      type nat hook input priority 105; policy accept;
    }

    chain NAT_OUTPUT {
      type nat hook output priority -95; policy accept;
    }

    chain NAT_POSTROUTING {
      type nat hook postrouting priority 105; policy accept;

      # The WAN address is dynamic, so masquerade everything leaving eth1.
      # Traffic between LTNET and 192.168.30.0/24 retains its source address.
      meta nfproto ipv4 oifname "eth1" masquerade
    }
  '';
}
