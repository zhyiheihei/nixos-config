{ lib, ... }:
{
  imports = [
    ../../nixos/minimal.nix
    ./hardware-configuration.nix
  ];

  # Use DHCP only during bring-up. Mainline Allwinner DT aliases normally
  # produce end0; eth0 is retained here for older naming policy revisions.
  systemd.network.networks."10-opi03-lan" = {
    matchConfig.Name = "end0 eth0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  # The installed board is the 4 GiB variant. zram is a safety margin for
  # activation and evaluation; this board must not become a build worker.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
}
