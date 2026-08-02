{
  config,
  lib,
  modulesPath,
  pkgs,
  self,
  ...
}:
let
  # U-Boot is target firmware, but all compiler processes should execute
  # natively on the dedicated x86_64 builder rather than on a small ARM node.
  crossPkgs =
    self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform;
  ubootOrangePiZero3 = crossPkgs.ubootOrangePiZero3.overrideAttrs (old: {
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
  });
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
    (modulesPath + "/installer/sd-card/sd-image.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    # Unlike the RK356x boards, this host uses the cached generic arm64 kernel.
    # Keep the real SD/MMC host driver available in initrd: an empty
    # modules-shrunk closure is invalid, while unrelated x86 storage modules
    # from the generic SD-image profile are neither useful nor guaranteed to
    # exist on arm64.
    # The stock initrd set contains unrelated SATA/NVMe/USB drivers. Disable
    # that generic set, then let filesystem modules append their own required
    # drivers. In particular, NixOS must add and force-load btrfs because /nix
    # is needed during stage 1 and BTRFS_FS=m in the generic arm64 kernel.
    initrd.includeDefaultModules = false;
    initrd.availableKernelModules = [ "sunxi_mmc" ];
    initrd.systemd.tpm2.enable = false;
    # The common kernel module enables nullfsvfs unconditionally. This board
    # deliberately drops that out-of-tree module, but must retain the btrfs
    # module contributed by nixos/modules/tasks/filesystems/btrfs.nix.
    initrd.kernelModules.nullfsvfs = lib.mkForce false;
    kernelModules = lib.mkForce [ ];
    extraModulePackages = lib.mkForce [ ];
    kernelParams = [
      # H616/H618 UART0. Keep baud out of earlycon so the real 8250 driver can
      # take over cleanly; the normal console carries the 115200 setting.
      "earlycon=uart8250,mmio32,0x05000000"
      "console=ttyS0,115200n8"
      "console=tty0"
      "rootwait"
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

  # Linux 6.18 has the Orange Pi Zero 3 DT and all boot-critical H618 drivers.
  # Reuse the cacheable Nixpkgs kernel instead of cloning another full config.
  lantian.kernel = lib.mkForce pkgs.linux_6_18;

  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    # installer/sd-card/sd-image.nix otherwise enables the all-hardware module,
    # which injects x86 RAID/SATA drivers such as 3w-9xxx into this arm64
    # initrd and can make modules-shrunk fail before an image is produced.
    enableAllHardware = lib.mkForce false;
    # Ethernet and SD boot need no external firmware. The onboard AW859A
    # Wi-Fi/Bluetooth path uses the out-of-tree uwe5622 stack and is deliberately
    # deferred until the first hardware inventory confirms its exact interface.
    enableRedistributableFirmware = lib.mkForce false;
    firmware = lib.mkForce [ ];
    deviceTree = {
      name = "allwinner/sun50i-h618-orangepi-zero3.dtb";
      filter = "sun50i-h618-orangepi-zero3.dtb";
    };
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

  # The generic grow service inspects /, but this image stores the persistent
  # filesystem at /nix. Grow partition 2 and its Btrfs filesystem once the
  # compact image has booted from a larger SD card.
  systemd.services.opi03-grow-nix = {
    description = "Expand Orange Pi Zero 3 persistent Nix filesystem";
    wantedBy = [ "multi-user.target" ];
    after = [ "nix.mount" ];
    requires = [ "nix.mount" ];
    before = [ "sops-install-secrets.service" ];
    path = [
      pkgs.btrfs-progs
      pkgs.gptfdisk
      pkgs.gnugrep
      pkgs.gnused
      pkgs.parted
      pkgs.util-linux
    ];
    script = ''
      nix_device=$(findmnt --noheadings --output SOURCE --target /nix | sed 's/\[.*//')
      nix_device=$(readlink -f "$nix_device")
      disk="/dev/$(lsblk --noheadings --output PKNAME "$nix_device" | tr -d '[:space:]')"
      partition=$(lsblk --noheadings --output PARTN "$nix_device" | tr -d '[:space:]')

      test -b "$nix_device"
      test -b "$disk"
      test -n "$partition"
      current_end=$(sgdisk -i "$partition" "$disk" | sed -n 's/^Last sector: \([0-9][0-9]*\).*/\1/p')
      usable_end=$(sgdisk -p "$disk" | sed -n 's/^First usable sector is [0-9][0-9]*, last usable sector is \([0-9][0-9]*\).*/\1/p')

      if [ "$current_end" -lt "$usable_end" ]; then
        sgdisk -e "$disk"
        printf 'Yes\n' | parted ---pretend-input-tty "$disk" resizepart "$partition" 100%
        partx -u "$disk"
      fi

      btrfs filesystem resize max /nix
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  sdImage = {
    # Allwinner BROM reads the combined SPL/U-Boot image at 8 KiB. Keep the
    # first partition at 16 MiB so neither the payload nor future growth can
    # overlap the FAT filesystem.
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
    rootPartitionUUID = "dbd98f41-817f-4511-a91f-b26a9b6ec7ba";
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
      dd if=${ubootOrangePiZero3}/u-boot-sunxi-with-spl.bin \
        of="$img" bs=1024 seek=8 conv=notrunc status=none
    '';
  };
}
