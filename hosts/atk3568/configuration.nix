{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/minimal.nix
    ./hardware-configuration.nix
  ];

  # Bring-up image: both RK3568 GMACs are equivalent until the first serial log,
  # so match the driver and let DHCP place the board on the LAN.
  systemd.network.networks."10-atk3568-lan" = {
    matchConfig = {
      Name = "eth*";
      Driver = "rk_gmac-dwmac";
    };
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  # Bring-up only: the serial console is the only path into an image whose
  # Ethernet is still being characterised. Remove together with the tools below.
  services.getty.autologinUser = "root";

  environment.systemPackages = with pkgs; [
    ethtool
    i2c-tools
    libgpiod
    mdio-tools
    mmc-utils
    pciutils
    usbutils
  ];
}
