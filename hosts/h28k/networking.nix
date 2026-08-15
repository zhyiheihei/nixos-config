{ ... }:
{
  systemd.network.networks = {
    # LAN: the integrated GMAC (eth0) owns the site subnet 192.168.30.0/24.
    # Kea (dhcp.nix) serves addresses from the .100-.249 pool with gateway and
    # DNS at 192.168.30.1; no DHCP client runs here.
    "10-h28k-lan" = {
      matchConfig.Name = "eth0";
      address = [ "192.168.30.1/24" ];
      networkConfig.IPv6AcceptRA = false;
      linkConfig.RequiredForOnline = "no";
    };

    # WAN: the PCIe RTL8111H (eth1) is an IPv4 DHCP uplink that ignores the
    # upstream DNS servers. Works unchanged with any upstream DHCP network.
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
