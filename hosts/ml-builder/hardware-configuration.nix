{
  config,
  lib,
  ...
}:
{
  imports = [
    ../../nixos/hardware/gpu-unlock.nix
    ../../nixos/hardware/nvidia/only.nix
  ];

  hardware.nvidia.package = lib.mkForce config.boot.kernelPackages.nvidiaPackages.latest;

  lantian.gpuUnlockTargets = "0000:01:00.0";

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
    gfxmodeBios = "2560x1440x32,auto";
    gfxmodeEfi = "2560x1440x32,auto";
  };

  boot.initrd.availableKernelModules = [
    "ahci"
    "nvme"
    "sd_mod"
    "usb_storage"
    "usbhid"
    "xhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  boot.initrd.luks.devices."root" = {
    allowDiscards = true;
    bypassWorkqueues = true;
    crypttabExtraOpts = [ "fido2-device=auto" ];
    device = "/dev/disk/by-uuid/28b8bd29-1c6e-4e6c-9180-b0629de14e53";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/1BC7-1AE2";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
      "nosuid"
      "nodev"
      "noexec"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/mapper/root";
    fsType = "btrfs";
    neededForBoot = true;
    options = [
      "subvol=@nix"
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  swapDevices = [
    {
      device = "/dev/disk/by-id/nvme-Netac_NVMe_SSD_2TB_TeNaFe202309192T4364-part3";
      randomEncryption.enable = true;
    }
  ];

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
