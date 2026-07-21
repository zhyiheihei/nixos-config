# BIOS QEMU VM; disk layout verified from the Alpine installer.
_: {
  imports = [
    ../../nixos/hardware/qemu.nix
  ];

  boot.loader.grub.device = "/dev/vda";

  fileSystems."/nix" = {
    device = "/dev/vda2";
    fsType = "btrfs";
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/vda1";
    fsType = "ext4";
  };

  swapDevices = [ ];
}
