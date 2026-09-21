# UEFI 两分区布局（512M ESP + Btrfs 三子卷 nix/persistent/persistent-home，
# tmpfs /）。UUID 为 2026-09-21 安装现场 blkid 实测值（KIOXIA EXCERIA 465.8G，
# S/N 51IA21S3K2Q2）。
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "nvme"
    "usb_storage"
    "sd_mod"
    "usbhid"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/B59F-1E2F";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/d31aa59a-3616-413f-b4be-797f78b46827";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "subvol=nix"
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  fileSystems."/nix/persistent" = {
    device = "/dev/disk/by-uuid/d31aa59a-3616-413f-b4be-797f78b46827";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "subvol=persistent"
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  fileSystems."/nix/persistent/home" = {
    device = "/dev/disk/by-uuid/d31aa59a-3616-413f-b4be-797f78b46827";
    fsType = "btrfs";
    options = [
      "subvol=persistent/home"
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # Intel 平台微码 + 自由固件（i7-8550U）。
  hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  hardware.enableRedistributableFirmware = true;
}
