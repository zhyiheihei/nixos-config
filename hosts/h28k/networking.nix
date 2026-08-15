{ ... }:
let
  # The remote-site uplink rate is not known yet; CAKE shaping must match the
  # real WAN bandwidth after relocation. 1G matches the current home staging
  # switch port.
  wanBandwidth = "1G";
in
{
  systemd.network.networks = {
    # WAN: the PCIe RTL8111H is an IPv4 DHCP uplink shaped by CAKE (the
    # author's router recipe: dual-src-host flow isolation + NAT + diffserv8,
    # see nixos-config-exam/hosts/lt-home-router/networking.nix).
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
      cakeConfig = {
        Bandwidth = wanBandwidth;
        FlowIsolationMode = "dual-src-host";
        NAT = true;
        PriorityQueueingPreset = "diffserv8";
      };
    };

    # LAN: the integrated GMAC (eth0) owns the site subnet 192.168.30.0/24.
    # Kea (dhcp.nix) serves addresses from the .100-.249 pool with gateway and
    # DNS at 192.168.30.1; no DHCP client runs here.
    "10-h28k-lan" = {
      matchConfig.Name = "eth0";
      address = [ "192.168.30.1/24" ];
      networkConfig.IPv6AcceptRA = false;
      linkConfig.RequiredForOnline = "no";
    };
  };
}
