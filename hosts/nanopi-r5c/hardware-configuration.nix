{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  ubootNanoPiR5C = pkgs.ubootNanoPiR5S.override {
    defconfig = "nanopi-r5c-rk3568_defconfig";
  };
in
{
  imports = [
    (modulesPath + "/installer/sd-card/sd-image-aarch64.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    initrd.availableKernelModules = [
      "mmc_block"
      "nvme"
      "r8169"
    ];
    initrd.kernelModules = [ "r8169" ];
    kernelModules = [ "r8169" ];
    kernelPackages = lib.mkForce pkgs.linuxPackages_6_18;
    kernelParams = [
      "console=ttyS2,1500000"
      "console=tty0"
    ];
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "ext4"
      "vfat"
    ];
    zfs.forceImportRoot = false;

    loader = {
      generic-extlinux-compatible.enable = lib.mkForce true;
      grub.enable = lib.mkForce false;
    };
  };

  hardware.deviceTree.name = "rockchip/rk3568-nanopi-r5c.dtb";

  fileSystems = {
    "/" = lib.mkForce {
      device = "tmpfs";
      fsType = "tmpfs";
      options = [
        "mode=755"
        "nodev"
        "nosuid"
        "relatime"
        "size=80%"
      ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/FIRMWARE";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
    "/boot/firmware".enable = false;
    "/nix" = {
      device = "/dev/disk/by-label/NIXOS_NIX";
      fsType = "btrfs";
      neededForBoot = true;
      options = [
        "compress-force=zstd"
        "autodefrag"
        "nosuid"
        "nodev"
      ];
    };
  };

  # Keep the first partition beyond both Rockchip bootloader payloads:
  # idbloader.img at 32 KiB and u-boot.itb at 8 MiB.
  sdImage = {
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    rootFilesystemCreator = ./make-nix-btrfs-fs.nix;
    rootVolumeLabel = "NIXOS_NIX";
    nixPathRegistrationFile = "/nix/nix-path-registration";
    compressImage = true;
    populateFirmwareCommands = ''
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -c ${config.system.build.toplevel} \
        -d firmware
    '';
    populateRootCommands = ''
      mkdir -p files/persistent/etc/ssh files/var/nix/profiles
      ln -s ${config.system.build.toplevel} files/var/nix/profiles/system
    '';
    postBuildCommands = ''
      dd if=${ubootNanoPiR5C}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootNanoPiR5C}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
