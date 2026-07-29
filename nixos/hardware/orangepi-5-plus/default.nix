{
  config,
  lib,
  modulesPath,
  pkgs,
  self,
  ...
}:
let
  # Avoid running the ARM64 GCC, assembler and linker themselves through
  # qemu-user on x86_64 builders.  This package set runs a native x86_64 cross
  # toolchain and produces the same aarch64-linux kernel outputs.
  crossPkgs =
    self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform;

  # Nixpkgs already provides a complete RK3588 boot chain for this board:
  # U-Boot 2026.04 + armTrustedFirmwareRK3588 + rkbin TPL.
  # No defconfig override is needed.
  inherit (pkgs) ubootOrangePi5Plus;

  # Keep the mainline kernel while using Armbian's proven RK3588 config as the
  # platform baseline.  linux_6_18.override silently ignores a configfile
  # argument; linuxManualConfig actually applies the complete olddefconfig
  # result and retains the standard out/dev/modules outputs.
  # Source: armbian-build/config/kernel/linux-rockchip-rk3588-current.config
  # Already includes: DRM_PANTHOR=m, ANDROID_BINDER_IPC=y, ANDROID_BINDERFS=y,
  # DMABUF_HEAPS=y, PSI=y, IKCONFIG=y, STMMAC/DWMAC_ROCKCHIP=y, R8169=m,
  # BTRFS/EXT4/VFAT=y, MMC_SDHCI_OF_DWCMSHC=y, NVME_CORE=y.
  opi5pKernel = crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_6_18) src version modDirVersion;
    configfile = ./kernel-config;
  };

  savedClock = "/nix/persistent/var/lib/opi5p-clock/epoch";
  saveClock = pkgs.writeShellScript "opi5p-save-clock" ''
    install -d -m 0700 "$(dirname ${savedClock})"
    date +%s > ${savedClock}.new
    chmod 0600 ${savedClock}.new
    mv ${savedClock}.new ${savedClock}
  '';
  restoreClock = pkgs.writeShellScript "opi5p-restore-clock" ''
    if test -s ${savedClock}; then
      date --utc --set="@$(cat ${savedClock})"
    fi
  '';

  # Mali-G610 CSF firmware required by the Panthor GPU driver.
  # Only pull the specific firmware files instead of the full 500 MB+
  # linux-firmware package.
  maliFirmware = pkgs.runCommand "mali-g610-firmware" {} ''
    fw=${pkgs.linux-firmware}
    mkdir -p $out/lib/firmware/arm/mali/arch10.8
    for f in $fw/lib/firmware/arm/mali/arch10.8/*; do
      cp -L "$f" $out/lib/firmware/arm/mali/arch10.8/ 2>/dev/null || true
    done
    # Also provide the legacy path some drivers expect
    mkdir -p $out/lib/firmware
    for f in $fw/lib/firmware/mali_csffw*.bin; do
      cp -L "$f" $out/lib/firmware/ 2>/dev/null || true
    done
  '';
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
    (modulesPath + "/installer/sd-card/sd-image.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    # With the Armbian-based config, storage drivers (MMC_SDHCI_OF_DWCMSHC,
    # NVME_CORE, BTRFS, EXT4, VFAT) are all builtin (=y).  This SD image does
    # not use a remote root, so do not inherit the generic ARM image's initrd
    # module list (which includes drivers such as 3w-9xxx that this targeted
    # kernel deliberately does not build).  Network drivers load after the
    # persistent root is mounted.
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = [ ];
    kernelModules = [
      "dwmac_motorcomm"
      "panthor"
      "r8169"
    ];
    kernelParams = [
      # RK3588 UART2 is at 0xfeb50000 (different from RK3568's 0xfe660000).
      # Do NOT append baud rate after the MMIO address; doing so hides all
      # output after U-Boot's "Starting kernel ..." line.
      "earlycon=uart8250,mmio32,0xfeb50000"
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
        # Keep two known-good generations without eventually filling the small
        # FAT boot partition with old kernels and initrds.
        configurationLimit = lib.mkForce 2;
      };
      grub = {
        enable = lib.mkForce false;
        extraInstallCommands = lib.mkForce "";
      };
    };
  };

  # Keep the author's kernel package wrapper so its custom module attributes
  # remain available on ARM, just as on lt-rpi4 and nanopi-r5c.
  lantian.kernel = lib.mkForce opi5pKernel;

  # This headless extlinux board never installs a GRUB theme.  Disable the
  # common theme units so their large source archive is absent from the image.
  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    # Install only the firmware requested by Panthor rather than retaining the
    # complete linux-firmware package in every system closure.
    enableRedistributableFirmware = lib.mkForce false;
    firmware = [ maliFirmware ];
  };

  hardware.deviceTree = {
    name = "rockchip/rk3588-orangepi-5-plus.dtb";
    # Only copy the target board DTB into /boot, avoiding 1000+ ARM64 DTBs.
    filter = "rk3588-orangepi-5-plus.dtb";
    overlays = [
      {
        name = "orangepi-5-plus-cooler-fan-curve";
        filter = "rk3588-orangepi-5-plus.dtb";
        dtsFile = ./cooler-fan-curve.dts;
      }
    ];
  };

  # RK3588 boards may return to a firmware timestamp after losing power.
  systemd = {
    services = {
      opi5p-restore-clock = {
        description = "Restore Orange Pi 5 Plus software clock";
        wantedBy = [ "multi-user.target" ];
        before = [ "ntpd-rs.service" ];
        requiredBy = [ "ntpd-rs.service" ];
        unitConfig.RequiresMountsFor = [ "/nix/persistent" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = restoreClock;
          ExecStop = saveClock;
        };
      };
      opi5p-save-clock = {
        description = "Save Orange Pi 5 Plus software clock";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = saveClock;
        };
      };
    };
    timers.opi5p-save-clock = {
      description = "Periodically save Orange Pi 5 Plus software clock";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
        Unit = "opi5p-save-clock.service";
      };
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

  # RK3588 boot layout: idbloader.img at 32 KiB, u-boot.itb at 8 MiB.
  # First partition starts at 16 MiB to avoid both payloads.
  sdImage = {
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ./make-nix-btrfs-fs.nix;
    rootPartitionUUID = "55555555-5555-5555-8888-888888888888";
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
      mkdir -p \
        files/persistent/etc/ssh \
        files/var/nix/daemon-socket \
        files/var/nix/profiles
      # preservation links /etc/machine-id here from the initrd.  Keep the
      # target empty in the image so systemd assigns a unique ID on first boot.
      touch files/persistent/etc/machine-id
      ln -s ${config.system.build.toplevel} files/var/nix/profiles/system
    '';
    postBuildCommands = ''
      # Nixpkgs assumes extlinux lives on partition 2. This image puts it on the
      # FAT partition, so mark partition 1 (and only partition 1) bootable.
      sfdisk --activate "$img" 1
      dd if=${ubootOrangePi5Plus}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootOrangePi5Plus}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
