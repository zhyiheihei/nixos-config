{ ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ./ddns-gcore.nix
    ./dhcp.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix
    ./prometheus.nix
    ./wifi.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/client-components/multicast-dns.nix
    ./v2ray.nix
    ../../nixos/optional-apps/miniupnpd.nix
    ../../nixos/optional-apps/nmea-static-gps-server.nix
    ../../nixos/optional-apps/ncps-client.nix
  ];

  services.miniupnpd = {
    externalInterface = "ppp0";
    internalIPs = [ "br-lan" ];
  };
}
