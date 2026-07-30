{ lib, LT, ... }:
{
  imports = [
    ../../nixos/minimal.nix
    ../../nixos/hardware/rk3588-redroid.nix

    ./hardware-configuration.nix
  ];

  # ROCK 5C has one onboard Gigabit Ethernet controller. The initial image
  # deliberately matches its kernel name; replace this with PermanentMACAddress
  # after the first successful boot, as done for opi5p.
  systemd.network.networks."10-rock5c-lan" = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.Name = "eth0";
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;
}
