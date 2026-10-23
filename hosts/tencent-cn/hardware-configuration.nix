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
