{ LT, lib, ... }:
let
  ztRoutes = [
    { target = "198.18.0.0/24"; }
    { target = "fdd8:1938:4e88::/64"; }
  ];
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
