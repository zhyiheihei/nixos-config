{
  LT,
  lib,
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

      # Block forwarding from public interface
      iifname "eth0" drop
    }

    chain FILTER_OUTPUT {
      type filter hook output priority 5; policy accept;
    }

    chain NAT_PREROUTING {
      type nat hook prerouting priority -95; policy accept;

      # Port forwarding: WAN → colocrossing
      fib daddr type local tcp dport { 80, 443, 2222 } iifname "eth0" dnat ip to 192.168.0.52
      fib daddr type local udp dport { 80, 443 } iifname "eth0" dnat ip to 192.168.0.52

      # Hairpin NAT: LAN accessing public IP gets redirected to colocrossing
      fib daddr type local iifname "eth1" ip daddr != @RESERVED_IPV4 dnat ip to 192.168.0.52
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
      meta nfproto ipv4 oifname "eth1" ct status dnat masquerade
    }

    set PUBLIC_FIREWALLED_PORTS {
      type inet_service
      flags constant
      elements = {
        137,138,139,445,${LT.portStr.CUPS},${LT.portStr.Rsync},${LT.portStr.mDNS}
      }
    }

    chain PUBLIC_INPUT {
      tcp dport @PUBLIC_FIREWALLED_PORTS reject with tcp reset
      udp dport @PUBLIC_FIREWALLED_PORTS reject with icmpx type port-unreachable
      return
    }

    # IP Sets
    ${ipv4Set "RESERVED_IPV4" LT.constants.reserved.IPv4}
  '';
}
