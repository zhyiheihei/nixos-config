{ ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ../../nixos/common-apps/coredns.nix

    ./ddns-gcore.nix
    ./dhcp.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix
  ];
}
