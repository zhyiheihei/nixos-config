{ lib, ... }:
{
  imports = [
    ../../nixos/minimal.nix
    ../../nixos/optional-apps/ncps-client.nix
    ./hardware-configuration.nix
  ];

  systemd.network.networks."10-opi03-lan" = {
    matchConfig.Name = "end0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
}
