{ LT, ... }:
{
  systemd.network.networks = {
    # The integrated GMAC/PHY is eth0. During staging both ports are DHCP
    # clients so the board stays reachable whichever port is plugged into
    # the upstream router (eth1 carries the primary route).
    "10-h28k-lan" = {
      matchConfig.Name = "eth0";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
      };
      dhcpV4Config = {
        RouteMetric = 200;
        UseDNS = false;
      };
      linkConfig.RequiredForOnline = "no";
    };

    # The PCIe RTL8111H enumerates as eth1 and is the WAN port. During staging
    # it receives a 192.168.0.x lease from the current router; after relocation
    # it works unchanged with any upstream IPv4 DHCP network.
    "10-h28k-wan" = {
      matchConfig.Name = "eth1";
      networkConfig = {
        DHCP = "ipv4";
        IPv6AcceptRA = false;
      };
      dhcpV4Config = {
        RouteMetric = 100;
        UseDNS = false;
      };
      linkConfig.RequiredForOnline = "routable";
    };
  };
}
