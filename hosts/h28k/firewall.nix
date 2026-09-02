{
  config,
  lib,
  LT,
  ...
}:
let
  # Ports that must never be exposed on the untrusted WAN side. Same list as
  # the author's lt-home-router (nixos-config-exam/hosts/lt-home-router/
  # firewall.nix).
  publicFirewalledPorts = [
    137
    138
    139
    445
    LT.port.CUPS
    LT.port.Rsync
    LT.port.NMEA
    LT.port.mDNS
  ];

  setOf = name: value: ''
    set ${name} {
      type ipv4_addr
      flags constant, interval
      elements = { ${builtins.concatStringsSep ", " value} }
    }
  '';
in
{
  # The repository-wide prefix classifier treats both eth0 and eth1 as WAN.
  # Override it for this two-port router so eth0 is trusted LAN and eth1 is an
  # untrusted DHCP uplink. Firewall model mirrors the author's lt-home-router:
  # input/output default to accept with explicit drops for timestamp ICMP,
  # ZeroTier mDNS and the never-exposed ports on the WAN. The earlier
  # drop-by-default input chain was a deviation from upstream and silently cut
  # off the Colmena deploy path (SSH over ZeroTier/LTNET on zt*).
  networking.nftables.tables.lantian.content = lib.mkForce ''
    chain FILTER_INPUT {
      type filter hook input priority 5; policy accept;

      # Drop timestamp ICMP pkts (author's router recipe)
      meta l4proto icmp icmp type timestamp-reply drop
      meta l4proto icmp icmp type timestamp-request drop

      # Block Avahi Multicast DNS on ZeroTier
      iifname "zt*" udp sport 5353 reject
      iifname "zt*" udp dport 5353 reject

      # WAN is an IPv4-only DHCP uplink
      iifname "eth1" meta nfproto ipv6 drop

      iifname "eth1" jump PUBLIC_INPUT
    }

    chain FILTER_FORWARD {
      type filter hook forward priority 5; policy accept;

      # Clamp TCP MSS
      tcp flags syn tcp option maxseg size set rt mtu

      ct state { established, related } accept
      ct status dnat accept

      # Block new connections from the public interface
      iifname "eth1" drop
    }

    chain FILTER_OUTPUT {
      type filter hook output priority 5; policy accept;

      # Block Avahi Multicast DNS on ZeroTier
      oifname "zt*" udp sport 5353 reject
      oifname "zt*" udp dport 5353 reject

      # Never leak the firewalled ports out the WAN (author's recipe)
      oifname "eth1" fib saddr type local jump PUBLIC_OUTPUT
    }

    chain NAT_PREROUTING {
      type nat hook prerouting priority -95; policy accept;

      # CoreDNS runs in its client namespace; present it to LAN clients at the
      # router gateway address on both TCP and UDP port 53.
      fib daddr type local tcp dport ${LT.portStr.DNS} iifname "eth0" dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}
      fib daddr type local udp dport ${LT.portStr.DNS} iifname "eth0" dnat ip to ${config.lantian.netns.coredns-client.ipv4}:${LT.portStr.DNS}

      # Hairpin NAT: LAN clients reach forwarded services through the gateway
      # address too; RESERVED_IPV4 keeps internal destinations un-NATed
      # (author's router recipe).
      fib daddr type local iifname "eth0" ip daddr != @RESERVED_IPV4 jump NAT_PORT_FORWARD
    }

    chain NAT_PORT_FORWARD {
      # Port forwards for site services are added here when they exist.
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
      # Traffic between LTNET and 192.168.30.0/24 retains its source address
      # (deviation from the author's `oifname != "eth0*"` rule, which would
      # also NAT ZeroTier/LTNET egress; the H28K plan keeps those un-NATed).
      meta nfproto ipv4 oifname "eth1" masquerade
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

    ${setOf "RESERVED_IPV4" LT.constants.reserved.IPv4}

    set PUBLIC_FIREWALLED_PORTS {
      type inet_service
      flags constant
      elements = {
        ${lib.concatMapStringsSep "," builtins.toString publicFirewalledPorts}
      }
    }
  '';
}
