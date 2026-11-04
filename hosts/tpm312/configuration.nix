{
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/ncps-client.nix
    ./hardware-configuration.nix
  ];

  systemd.network.networks."10-tpm312-lan" = {
    matchConfig.Name = "eth0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    gateway = [ "192.168.0.1" ];
    networkConfig.IPv6AcceptRA = true;
  };

  networking.networkmanager.enable = lib.mkForce false;

  # Bring-up only: the serial console is the only path into an image whose
  # eMMC, PHY timing and thermals are still being characterised. Remove once
  # the host is in the deploy set.
  services.getty.autologinUser = lib.mkForce "root";

  environment.systemPackages = with pkgs; [
    ethtool
    i2c-tools
    mmc-utils
    pciutils
    usbutils
  ];
}
