{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  # R5C and R5S share the RK3568 boot layout; select the board-specific
  # upstream defconfig while retaining the Nixpkgs U-Boot package structure.
  ubootNanoPiR5C = pkgs.ubootNanoPiR5S.override {
    defconfig = "nanopi-r5c-rk3568_defconfig";
  };
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
    (modulesPath + "/installer/sd-card/sd-image.nix")
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
    kernelParams = [
      # The uart8250 earlycon parser must not be given the baud rate here; doing
      # so hides all output after U-Boot's "Starting kernel ..." line.
      # The board-specific sd-image imports below deliberately avoid the generic
      # aarch64 image's ttyS0/ttyAMA0 parameters, leaving ttyS2 as the only
      # serial console so the real 8250 driver can replace earlycon cleanly.
      "earlycon=uart8250,mmio32,0xfe660000"
      "console=ttyS2,1500000n8"
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

  # Keep the author's kernel package wrapper so its custom module attributes
  # remain available on ARM, just as on lt-rpi4.
  lantian.kernel = lib.mkForce pkgs.linux_6_18;

  hardware.deviceTree = {
    name = "rockchip/rk3568-nanopi-r5c.dtb";
    # Follow lt-rpi4: only copy DTBs for the target board into /boot.
    filter = "rk3568-nanopi-r5c.dtb";
  };

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
    firmwareSize = 256;
    rootFilesystemCreator = ./make-nix-btrfs-fs.nix;
    rootPartitionUUID = "44444444-4444-4444-8888-888888888888";
    rootVolumeLabel = "NIXOS_NIX";
    nixPathRegistrationFile = "/nix/nix-path-registration";
    compressImage = true;
    # The generic grow service inspects /, but this host uses tmpfs / and keeps
    # the persistent filesystem at /nix. Grow partition 2 explicitly after the
    # first successful boot instead.
    expandOnBoot = false;
    populateFirmwareCommands = lib.mkForce ''
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -g 0 \
        -c ${config.system.build.toplevel} \
        -d firmware
    '';
    populateRootCommands = lib.mkForce ''
      mkdir -p files/persistent/etc/ssh files/var/nix/profiles
      # preservation links /etc/machine-id here from the initrd.  Keep the
      # target empty in the image so systemd assigns a unique ID on first boot.
      touch files/persistent/etc/machine-id
      ln -s ${config.system.build.toplevel} files/var/nix/profiles/system
    '';
    postBuildCommands = ''
      # Nixpkgs assumes extlinux lives on partition 2. This image puts it on the
      # FAT partition, so mark partition 1 (and only partition 1) bootable.
      sfdisk --activate "$img" 1
      dd if=${ubootNanoPiR5C}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootNanoPiR5C}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
