{ ... }:
{
  imports = [
    ../../nixos/hardware/disable-watchdog.nix
    ../../nixos/hardware/dragon-q8b
  ];

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/56C0-FB03";
    fsType = "vfat";
    options = [
      "fmask=0077"
      "dmask=0077"
    ];
  };

  fileSystems."/nix" = {
    device = "/dev/disk/by-uuid/66493006-e89d-41dc-800f-9c437b92474a";
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
    device = "/dev/disk/by-uuid/66493006-e89d-41dc-800f-9c437b92474a";
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
    device = "/dev/disk/by-uuid/66493006-e89d-41dc-800f-9c437b92474a";
    fsType = "btrfs";
    options = [
      "subvol=persistent/home"
      "compress-force=zstd"
      "autodefrag"
      "nosuid"
      "nodev"
    ];
  };

  hardware.enableRedistributableFirmware = true;
}