# Do not modify this file! It was generated for the VOLCENGINE QEMU guest.
_: {
  imports = [
    ../../nixos/hardware/qemu.nix
    # 对齐 exam alice（同款 QEMU guest）：禁用 virtio balloon，防内存气球干扰。
    ../../nixos/hardware/disable-balloon.nix
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
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  swapDevices = [
    {
      device = "/dev/vda3";
      randomEncryption.enable = true;
    }
  ];
}
