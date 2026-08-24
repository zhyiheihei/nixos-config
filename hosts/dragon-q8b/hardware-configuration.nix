{ ... }:
{
  imports = [
    ../../nixos/hardware/disable-watchdog.nix
  ];

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/DB72-1C49";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/e9ab9a38-49d2-48c9-a2b3-85dce405e99b";
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
    device = "/dev/disk/by-uuid/e9ab9a38-49d2-48c9-a2b3-85dce405e99b";
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
    device = "/dev/disk/by-uuid/e9ab9a38-49d2-48c9-a2b3-85dce405e99b";
    fsType = "btrfs";
    options = [
      "subvol=home"
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  hardware.enableRedistributableFirmware = true;
}