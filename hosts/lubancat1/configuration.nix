{ lib, ... }:
{
  imports = [
    ../../nixos/minimal.nix
    ./hardware-configuration.nix
  ];

  # The first image has no fixed address. Match both the legacy eth0 name
  # selected by the common networking module and systemd's embedded end0 name
  # so DHCP remains available while the final host identity is undecided.
  systemd.network.networks."10-lubancat1-lan" = {
    matchConfig.Name = "eth0 end0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  # The installed board has 2 GiB RAM. zram provides a small safety margin for
  # NixOS activation without turning this low-power board into a build worker.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
}
