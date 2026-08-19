# Do not modify this file's structure by hand beyond the disk UUIDS below!
# 生成模板按 UEFI 两分区布局（EFI /boot + Btrfs /nix + tmpfs /），Intel 平台。
# 分区完成后，把 `blkid` 现场读取的两个 UUID 分别填进 /boot 与 /nix，
# 并在 ml-builder 上 `nix eval` 确认后再构建闭包。
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  boot.initrd.availableKernelModules = [
    "ahci"
    "xhci_pci"
    "usbhid"
    "usb_storage"
    "sd_mod"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/A889-8907";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/6dad5c56-22d4-49c7-97f5-a225bb5f12cf";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
  # Intel 平台微码 + 自由固件（AX211 WiFi 固件在 linux-firmware，需
  # enableRedistributableFirmware 才能装入）。
  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
}
