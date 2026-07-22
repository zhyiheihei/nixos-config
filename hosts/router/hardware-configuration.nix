# Placeholder: replace with output of nixos-generate-config after VM installation.
{
  config,
  lib,
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/profiles/qemu-guest.nix") ];

  boot.initrd.availableKernelModules = [
    "virtio_pci"
    "virtio_scsi"
  ];
  boot.kernelModules = [ ];
  boot.extraModulePackages = [ ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
}
