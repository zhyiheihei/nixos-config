# Do not modify this file! It was generated for the logvm QEMU guest.
{
  lib,
  ...
}:
{
  imports = [
    ../../nixos/hardware/disable-watchdog.nix
    ../../nixos/hardware/qemu.nix
    ../../nixos/hardware/qemu-hotplug.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];
  boot.initrd.kernelModules = [ "virtiofs" ];
  boot.loader.grub.device = "/dev/sda";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/f838c78f-eca2-48d3-9ec0-e9471d42ea6e";
    fsType = "ext4";
  };

  fileSystems."/nix" = {
    device = "virtiofs-nixos-logvm";
    fsType = "virtiofs";
  };

  swapDevices = [
    {
      device = "/dev/disk/by-partuuid/7f822cbd-a26b-41eb-8360-1c7fa2259762";
      randomEncryption.enable = true;
    }
  ];

  services.qemuGuest.enable = true;
  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
