{ lib, ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ./dhcp.nix
    ./ddns.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix

    ../../nixos/common-apps/coredns.nix
    ../../nixos/client-components/multicast-dns.nix
    ../../nixos/optional-apps/miniupnpd.nix
  ];

  services.miniupnpd = {
    externalInterface = "eth1";
    internalIPs = [ "eth0" ];
  };

  networking.networkmanager.enable = lib.mkForce false;

  systemd.network.links = {
    "10-h28k-eth0" = {
      matchConfig.MACAddress = "3e:a8:c4:14:09:23";
      linkConfig.MACAddress = "3e:a8:c4:14:09:23";
    };
    "10-h28k-eth1" = {
      matchConfig.Driver = "r8169";
      linkConfig.MACAddress = "3e:b9:d9:35:dc:2d";
    };
  };

  services.mptcpd.enable = lib.mkForce false;
}
