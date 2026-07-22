{ ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ./ddns-gcore.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix
  ];
}
