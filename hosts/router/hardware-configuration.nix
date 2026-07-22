{ ... }:
{
  imports = [
    ../../nixos/hardware/disable-watchdog.nix
    ../../nixos/hardware/qemu.nix
    ../../nixos/hardware/qemu-hotplug.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/6737-200C";
    fsType = "vfat";
    options = [ "fmask=0077" "dmask=0077" ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/cc86ac68-e7cf-4d88-859c-4e6582d28d21";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  services.qemuGuest.enable = true;
}
