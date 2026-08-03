{ LT, lib, ... }:
let
  # ZT default gateway. ml-home-vm went offline on 2026-08-03; ROCK 5C (the
  # home edge/control plane) now forwards ZT managed routes for the network.
  defaultGatewayHost = LT.hosts.rock5c;
  managedIPv4Ranges = LT.constants.dn42.IPv4 ++ LT.constants.neonetwork.IPv4 ++ [ "198.18.0.0/15" ];
  managedIPv6Ranges =
    LT.constants.dn42.IPv6 ++ LT.constants.neonetwork.IPv6 ++ [ "fdd8:1938:4e88::/48" ];

  ztRoutes = [
    { target = "198.18.0.0/24"; }
    { target = "fdd8:1938:4e88::/64"; }

    # Default routing to home router
    {
      target = "0.0.0.0/0";
      via = defaultGatewayHost.ltnet.IPv4;
    }
    {
      target = "::/0";
      via = defaultGatewayHost.ltnet.IPv6;
    }
    # SideStore
    {
      target = "10.7.0.1/32";
      via = defaultGatewayHost.ltnet.IPv4;
    }
  ]
  # Managed IP ranges
  ++ (builtins.map (r: {
    target = r;
    via = defaultGatewayHost.ltnet.IPv4;
  }) managedIPv4Ranges)
  ++ (builtins.map (r: {
    target = r;
    via = defaultGatewayHost.ltnet.IPv6;
  }) managedIPv6Ranges);
in
{
  services.zerotierone.controller = {
    enable = true;
    port = 9994;
    networks = {
      "000001" = {
        name = "ltnet";
        mtu = 1400;
        multicastLimit = 256;
        routes = ztRoutes;
        members = LT.zerotier.hosts;
        relays = lib.mapAttrsToList (n: v: v.zerotier) (
          lib.filterAttrs (n: v: v.zerotier != null) (LT.hostsWithTag LT.tags.server)
        );
        dns = {
          servers = [ "198.19.0.253" "fdd8:1938:4e88:3712::53" ];
        };
      };
    };
  };
}
