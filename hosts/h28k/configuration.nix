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

  # Fix stable MAC addresses. The RK3528 GMAC reads its address from the
  # board DT (stable across boots), but the PCIe RTL8111H has no programmed
  # EEPROM MAC and would otherwise get a different address per image or
  # machine-id, breaking DHCP identity and IP stability. Pin both NICs to
  # fixed locally-administered addresses so DHCP reservations and firewall
  # rules keep working across reflashes.
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

  # One DHCP uplink does not benefit from a userspace MPTCP path manager. It
  # also removes a nonessential failure point from the first router image.
  services.mptcpd.enable = lib.mkForce false;
}
