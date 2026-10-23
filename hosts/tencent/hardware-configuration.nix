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
