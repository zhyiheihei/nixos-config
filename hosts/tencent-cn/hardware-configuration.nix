# Tencent Cloud CVM (Shanghai) storage layout, following the project's unified
# server architecture: tmpfs / (impermanence), dedicated /boot, persistent
# btrfs /nix with neededForBoot = true.
#
# BIOS layout (confirmed in install env: test -d /sys/firmware/efi
# → BIOS): 2 MiB bios_grub (unmounted) + 1 GiB ext4 /boot + btrfs /nix.
# boot.loader.grub.device = "/dev/vda". UUIDs read from blkid in the
# Alpine RAM install environment (2026-09-23).
_: {
  imports = [
    ../../nixos/hardware/qemu.nix
  ];

  boot.loader.grub.device = "/dev/vda";

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/ff803ebc-e7fd-4efd-9e4a-a62fec598ff6";
    fsType = "ext4";
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/e9529c81-1b74-4416-91ef-12e01fdb7483";
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
