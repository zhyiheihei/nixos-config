{
  modulesPath,
  ...
}:
{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  fileSystems."/nix" = {
    device = "/dev/disk/by-label/nixos";
    fsType = "ext4";
    neededForBoot = true;
    options = [
      "noatime"
      "nosuid"
      "nodev"
    ];
  };

  swapDevices = [ ];
}
