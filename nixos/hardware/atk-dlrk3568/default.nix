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
  crossPkgs = self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform;

  # ATK-DLRK3568 is Rockchip's RK3568 EVB1 reference design with the ATK-CLRK3568F
  # SoM: RK809 PMIC, two YT8531C (RTL8211F-compatible) gigabit PHYs on GMAC0/GMAC1,
  # eMMC on sdhci, microSD on sdmmc0 and UART2 as the debug console. Mainline has
  # no board DTS yet, so start from the mainline EVB1 DTB (same RGMII wiring and
  # same PMIC) and reuse the repository's validated RK356x kernel baseline.
  atkKernel = crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_6_18) src version modDirVersion;
    configfile = ../nanopi-r5c/kernel-config;
  };

  # Mainline U-Boot has no ATK defconfig; the generic RK3568 target uses the same
  # TPL/BL31 chain as the NanoPi R5C package and boots any RK3568 board from SD.
  ubootAtk3568 = (crossPkgs.ubootNanoPiR5S.override {
    defconfig = "generic-rk3568_defconfig";
  }).overrideAttrs
    (old: {
      requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
    });

  # The board carries an AT8563T (PCF8563-compatible) RTC with a coin cell, but the
  # EVB1 DTB has no node for it, so until the board DTS is written preserve a recent
  # epoch on the persistent filesystem for TLS, SOPS and service ordering.
  savedClock = "/nix/persistent/var/lib/atk3568-clock/epoch";
  saveClock = pkgs.writeShellScript "atk3568-save-clock" ''
    install -d -m 0700 "$(dirname ${savedClock})"
    date +%s > ${savedClock}.new
    chmod 0600 ${savedClock}.new
    mv ${savedClock}.new ${savedClock}
  '';
  restoreClock = pkgs.writeShellScript "atk3568-restore-clock" ''
    if test -s ${savedClock}; then
      date --utc --set="@$(cat ${savedClock})"
    fi
  '';
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
    (modulesPath + "/installer/sd-card/sd-image.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    # The RK3568 storage, serial, PMIC and Ethernet drivers are built into the
    # generic arm64 kernel; keep the shrunk initrd free of unrelated root modules.
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = lib.mkForce [ ];
    kernelModules = lib.mkForce [
      "rtc_pcf8563"
      "wireguard"
    ];
    extraModulePackages = lib.mkForce [ ];
    # ttyS2 must stay the last console= so /dev/console lands on the debug UART.
    kernelParams = [
      "earlycon=uart8250,mmio32,0xfe660000"
      "console=tty0"
      "console=ttyS2,1500000n8"
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

  # The repository-wide kernel wrapper around the targeted RK356x build.
  lantian.kernel = lib.mkForce atkKernel;

  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    enableRedistributableFirmware = lib.mkForce false;
    firmware = lib.mkForce [ ];
    wirelessRegulatoryDatabase = true;
    bluetooth.enable = false;
  };

  hardware.deviceTree = {
    name = "rockchip/rk3568-evb1-v10.dtb";
    filter = "rk3568-evb1-v10.dtb";
    overlays = [
      {
        name = "atk3568-board";
        dtsFile = ./rk3568-atk-dlrk3568-overlay.dts;
      }
    ];
  };

  networking.networkmanager.enable = lib.mkForce false;

  systemd.services.atk3568-restore-clock = {
    description = "Restore ATK-DLRK3568 software clock";
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = restoreClock;
    };
  };
  systemd.timers.atk3568-save-clock = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Unit = "atk3568-save-clock.service";
    };
  };
  systemd.services.atk3568-save-clock = {
    description = "Periodically save ATK-DLRK3568 software clock";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = saveClock;
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

  # The image ships a compact Btrfs store and tmpfs `/`, so Nixpkgs' generic root
  # growth service cannot find the persistent partition; grow it explicitly.
  systemd.services.atk3568-grow-nix = {
    description = "Expand ATK-DLRK3568 persistent Nix filesystem";
    wantedBy = [ "multi-user.target" ];
    after = [ "nix.mount" ];
    requires = [ "nix.mount" ];
    before = [ "sops-install-secrets.service" ];
    path = [
      pkgs.btrfs-progs
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
      parted ---pretend-input-tty "$disk" resizepart "$partition" 100% <<<Yes 2>/dev/null || true
      partx -u "$disk" 2>/dev/null || true

      btrfs filesystem resize max /nix
    '';
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
  };

  sdImage = {
    # Reserve the standard Rockchip loader regions before the first partition:
    # idbloader at 32 KiB and U-Boot proper at 8 MiB.
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
    rootPartitionUUID = "6fa1c2c4-91a7-4fd0-9a11-5c4b2a0d7e63";
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
      dd if=${ubootAtk3568}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootAtk3568}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
