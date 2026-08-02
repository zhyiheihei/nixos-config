{
  config,
  lib,
  modulesPath,
  pkgs,
  self,
  ...
}:
let
  # Keep kernel and U-Boot compiler processes native on ml-builder while they
  # emit aarch64 binaries. The board itself must not compile its own kernel.
  crossPkgs =
    self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform;

  # Mainline U-Boot has no LubanCat-1 defconfig. Its generic RK3568 target is
  # intentionally board-neutral and uses the same RK3566/RK3568 TPL and BL31
  # boot chain as Nixpkgs' Orange Pi 3B package. Linux later receives the exact
  # rk3566-lubancat-1 DTB from extlinux.
  ubootLubanCat1 = pkgs.ubootOrangePi3B.override {
    defconfig = "generic-rk3568_defconfig";
  };
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
    (modulesPath + "/installer/sd-card/sd-image.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    # The RK3566 storage, serial, PMIC and Ethernet drivers are built into the
    # generic arm64 kernel. Avoid importing unrelated x86 root modules into the
    # shrunk initrd.
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = lib.mkForce [ ];
    kernelModules = lib.mkForce [ ];
    extraModulePackages = lib.mkForce [ ];
    kernelParams = [
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
      generic-extlinux-compatible = {
        enable = lib.mkForce true;
        configurationLimit = lib.mkForce 2;
      };
      grub = {
        enable = lib.mkForce false;
        extraInstallCommands = lib.mkForce "";
      };
    };
  };

  fileSystems."/run/nullfs".enable = lib.mkForce false;

  # Linux 6.18 already contains the original, non-V2 LubanCat-1 DTS. Use the
  # cross package directly and retain the repository's kernel package wrapper.
  lantian.kernel = lib.mkForce crossPkgs.linux_6_18;

  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  # The base board has no wireless adapter and its onboard devices need no
  # redistributable firmware. Add only the selected Mini PCIe card's firmware
  # after it is installed and identified.
  hardware.enableRedistributableFirmware = lib.mkForce false;

  hardware.deviceTree = {
    name = "rockchip/rk3566-lubancat-1.dtb";
    filter = "rk3566-lubancat-1.dtb";
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

  sdImage = {
    # Reserve the standard Rockchip loader regions before the first partition:
    # idbloader at 32 KiB and U-Boot proper at 8 MiB.
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
    rootPartitionUUID = "3488f167-0979-4fc2-b44a-4db8c1c51ccb";
    rootVolumeLabel = "NIXOS_NIX";
    nixPathRegistrationFile = "/nix/nix-path-registration";
    compressImage = true;
    expandOnBoot = false;
    populateFirmwareCommands = lib.mkForce ''
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} \
        -g 0 \
        -c ${config.system.build.toplevel} \
        -d firmware
    '';
    populateRootCommands = lib.mkForce ''
      mkdir -p \
        files/persistent/etc/ssh \
        files/var/nix/daemon-socket \
        files/var/nix/profiles
      touch files/persistent/etc/machine-id
      ln -s ${config.system.build.toplevel} files/var/nix/profiles/system
    '';
    postBuildCommands = ''
      sfdisk --activate "$img" 1
      dd if=${ubootLubanCat1}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootLubanCat1}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
