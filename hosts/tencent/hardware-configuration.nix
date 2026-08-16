# Tencent Cloud CVM (Seoul) storage layout, following the project's unified
# server architecture: tmpfs / (impermanence), dedicated /boot, persistent
# btrfs /nix with neededForBoot = true.
#
# BIOS layout (confirmed in install env: test -d /sys/firmware/efi → BIOS):
# - 2 MiB bios_grub (unmounted) + 1 GiB ext4 /boot + btrfs /nix
# - boot.loader.grub.device = "/dev/vda"
# Device paths were confirmed in the live install environment; UUIDs may be
# swapped in per docs/agent/nixos-reinstallation-guide.md §3.3.
_: {
  imports = [
    ../../nixos/hardware/qemu.nix
  ];

  boot.loader.grub.device = "/dev/vda";

  fileSystems."/boot" = {
    device = "/dev/vda2";
    fsType = "ext4";
  };

  fileSystems."/nix" = {
    device = "/dev/vda3";
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
