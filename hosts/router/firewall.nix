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

  publicFirewalledPorts = [
    # Samba
    137
    138
    139
    445
    LT.port.CUPS
    LT.port.Rsync
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

      iifname "eth0" jump PUBLIC_INPUT
    }

    chain FILTER_FORWARD {
      type filter hook forward priority 5; policy accept;

      # Clamp TCP MSS
      tcp flags syn tcp option maxseg size set rt mtu

      # Allow existing connections
      ct state { established, related } accept

      # Allow DNATed connections
      ct status dnat accept

      # Allow physical LAN (192.168.2.0/24) to reach virtual LAN
      iifname "eth0" ip saddr 192.168.2.0/24 ip daddr 192.168.0.0/24 accept

      # Block forwarding from public interface
      iifname "eth0" drop
    }

    chain FILTER_OUTPUT {
      type filter hook output priority 5; policy accept;

      # Block mDNS on WAN
      fib saddr type local oifname "eth0" jump PUBLIC_OUTPUT
    }

    chain NAT_PREROUTING {
      type nat hook prerouting priority -95; policy accept;

      # Port forwarding: WAN → colocrossing
      fib daddr type local tcp dport { 80, 443, 2222 } iifname "eth0" dnat ip to 192.168.0.52
      fib daddr type local udp dport { 80, 443 } iifname "eth0" dnat ip to 192.168.0.52

      # Hairpin NAT: LAN accessing public IP gets redirected to colocrossing
      fib daddr type local iifname "br-lan" ip daddr != @RESERVED_IPV4 dnat ip to 192.168.0.52
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
      meta nfproto ipv4 oifname "eth0" masquerade

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
  '';
}
