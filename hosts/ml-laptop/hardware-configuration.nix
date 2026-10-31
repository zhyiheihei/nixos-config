{
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    (modulesPath + "/installer/scan/not-detected.nix")
    ../../nixos/hardware/nvidia/prime.nix

    ../../nixos/hardware/smart.nix
  ];

  boot.initrd.availableKernelModules = [
    "thunderbolt"
    "nvme"
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
      "nosuid"
      "nodev"
      "noexec"
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

  hardware.cpu.intel.updateMicrocode = true;
  hardware.enableRedistributableFirmware = true;
  powerManagement.cpuFreqGovernor = lib.mkDefault "schedutil";
}
