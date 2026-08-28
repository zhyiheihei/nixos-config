# GreenCloud APAC 存储 VPS：vda 40G 系统盘（BIOS 三分区），vdb 1T 数据盘。
# UUID 现场采集于 2026-08-29 Alpine RAM 安装环境。
_: {
  imports = [
    ../../nixos/hardware/qemu.nix
  ];

  boot.loader.grub.device = "/dev/vda";

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/ea2b4296-41e5-415b-bc88-1e782039958a";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/9e3b2164-de95-4c42-822a-cccfdd435276";
    fsType = "ext4";
  };

  # 1T 备份数据盘：SFTP chroot 与 S3 网关数据都在这里。
  fileSystems."/data" = {
    device = "/dev/disk/by-uuid/8e931384-58ac-4b42-9264-3006972b2921";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "compress-force=zstd"
      "autodefrag"
    ];
  };

  swapDevices = [ ];
}
