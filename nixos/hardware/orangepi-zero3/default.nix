{
  config,
  lib,
  modulesPath,
  pkgs,
  self,
  ...
}:
let
  opi03Kernel = self.packages.x86_64-linux.opi03-redroid-kernel;
  opi03MaliKbase = self.packages.x86_64-linux.opi03-mali-kbase;

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
    # The targeted vendor config builds MMC, Btrfs, VFAT and ext4 into the
    # kernel.  Keep the generic SD-image profile from injecting unrelated SATA
    # and RAID modules which this H618 kernel intentionally does not build.
    initrd.includeDefaultModules = false;
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = lib.mkForce [ ];
    initrd.systemd.tpm2.enable = false;
    kernelModules = lib.mkForce [ "mali_kbase" ];
    extraModulePackages = lib.mkForce [ opi03MaliKbase ];
    kernelParams = [
      # H616/H618 UART0. Keep baud out of earlycon so the real 8250 driver can
      # take over cleanly; the normal console carries the 115200 setting.
      # The vendor 5.4 sunxi-uart driver registers the port as ttyAS0, not
      # ttyS0; console=ttyS0 never matches, so the bootconsole is dropped and
      # the serial goes silent after the UART probe.
      "earlycon=uart8250,mmio32,0x05000000"
      "console=ttyAS0,115200n8"
      "console=tty0"
      "rootwait"
      # Reserve enough contiguous memory for Mali buffers and Cedar video
      # surfaces.  This matches CONFIG_CMA_SIZE_MBYTES in the vendor config.
      "cma=256M"
    ];
    supportedFilesystems = lib.mkForce [
      "btrfs"
      "ext4"
      "vfat"
    ];
    # Orange Pi's 5.4 BSP predates mainline MPTCP.  Remove the repository-wide
    # sysctl instead of letting systemd-sysctl fail on a nonexistent key.
    kernel.sysctl."net.mptcp.enabled" = lib.mkForce null;
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

  # The same vendor-kernel limitation applies to the daemon and socket unit.
  # TCP keeps rsync available without pretending that this kernel has MPTCP.
  services.mptcpd.enable = lib.mkForce false;
  systemd.sockets.rsync.socketConfig.SocketProtocol = lib.mkForce "tcp";

  fileSystems."/run/nullfs".enable = lib.mkForce false;

  # reDroid needs a single matched BSP: vendor kernel/DT, Kbase r20 userspace
  # ABI and Cedar/ION.  Mixing the old Android blobs with mainline Panfrost is
  # explicitly unsupported and was already shown not to meet this project.
  lantian.kernel = lib.mkForce opi03Kernel;

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
      name = "sunxi/sun50i-h616-orangepi-zero3.dtb";
      filter = "sun50i-h616-orangepi-zero3.dtb";
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
