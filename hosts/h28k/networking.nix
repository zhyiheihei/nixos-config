{ LT, ... }:
{
  systemd.network.networks = {
    # The board documentation and upstream DTS map the integrated GMAC/PHY to
    # eth0. It is the isolated site LAN and never accepts a default route.
    "10-h28k-lan" = {
      matchConfig.Name = "eth0";
      address = [ "${LT.this.interconnect.IPv4}/24" ];
      networkConfig = {
        DHCP = "no";
        IPv6AcceptRA = false;
        LinkLocalAddressing = "no";
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
