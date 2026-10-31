_: {
  imports = [
    ../../nixos/hardware/qemu.nix
  ];

  boot.loader.grub.device = "/dev/vda";

  fileSystems."/nix" = {
    device = "/dev/vda3";
    fsType = "btrfs";
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/vda2";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
      "nosuid"
      "nodev"
      "noexec"
    ];
  };

  swapDevices = [ ];
}
