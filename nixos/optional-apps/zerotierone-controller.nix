{ LT, lib, ... }:
let
  inherit (LT) defaultGatewayHost;
  ztRoutes = [
    { target = "198.18.0.0/24"; }
    { target = "fdd8:1938:4e88::/64"; }

    {
      target = "192.168.3.0/24";
      via = "198.18.0.115";
    }

    # Default routing to home router
    {
      target = "0.0.0.0/0";
      via = defaultGatewayHost.ltnet.IPv4;
    }
    {
      target = "::/0";
      via = "fdd8:1938:4e88::204";
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
  }) LT.defaultGatewayHostIPv4Routes)
  ++ (builtins.map (r: {
    target = r;
    via = defaultGatewayHost.ltnet.IPv6;
  }) LT.defaultGatewayHostIPv6Routes);
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
        relays = lib.mapAttrsToList (n: v: v.zerotier) (LT.hostsWithTag LT.tags.server);
      };
    };
  };
}
