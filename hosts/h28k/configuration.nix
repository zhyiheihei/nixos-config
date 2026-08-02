{ lib, ... }:
{
  imports = [
    ../../nixos/minimal.nix

    ./dhcp.nix
    ./firewall.nix
    ./hardware-configuration.nix
    ./networking.nix

    ../../nixos/common-apps/coredns.nix
  ];

  networking.networkmanager.enable = lib.mkForce false;

  # One DHCP uplink does not benefit from a userspace MPTCP path manager. It
  # also removes a nonessential failure point from the first router image.
  services.mptcpd.enable = lib.mkForce false;

  # H28K is sold with several RAM sizes. A bounded compressed swap device is
  # safe for all variants and protects the router from transient activation
  # or DNS memory pressure without making it a build worker.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };
}
