# Tencent Cloud CVM (Seoul) storage layout, following the project's unified
# server architecture: tmpfs / (impermanence), dedicated /boot, persistent
# btrfs /nix with neededForBoot = true.
#
# Template for the initial install:
# - Confirm firmware in the install environment: test -d /sys/firmware/efi
# - UEFI: vda1 vfat /boot + vda2 btrfs /nix (as below)
# - BIOS: 2 MiB bios_grub + ext4 /boot + btrfs /nix, with
#   boot.loader.grub.device = "/dev/vda"
# - Replace the /dev/vda* device paths with the UUIDs read from the live
#   install environment (docs/operations/nixos-reinstallation-guide.md §3.3);
#   do not copy another machine's UUIDs.
_: {
  imports = [
    ../../nixos/hardware/qemu.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  fileSystems."/boot" = {
    device = "/dev/vda1";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/vda2";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };
}
