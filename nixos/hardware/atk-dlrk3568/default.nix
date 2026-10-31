{
  inputs,
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
  # eMMC on sdhci, microSD on sdmmc0 and UART2 as the debug console.
  atkKernelSrc = pkgs.runCommand "linux-dts-tree" { nativeBuildInputs = [ pkgs.xz ]; } ''
    mkdir -p $out
    tar -xJf ${crossPkgs.linux_6_18.src} -C $out --strip-components=1 \
      linux-*/include \
      linux-*/arch/arm64/boot/dts/rockchip \
      linux-*/scripts/dtc/include-prefixes
  '';

  atkKernel = crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_6_18) src version modDirVersion;
    configfile = ./kernel-config;
  };

  # Mainline rtw89 has no SDIO support for the RTL8852BS and linux-firmware ships
  # no firmware for it, so the vendor driver is the only way to drive the on-board
  # module.  Its firmware is compiled in (CONFIG_FILE_FWIMG = n), which is why the
  # module needs nothing from /lib/firmware.
  rtl8852bs = crossPkgs.stdenv.mkDerivation {
    pname = "rtl8852bs";
    version = "unstable-2026-09-10";
    src = pkgs.fetchFromGitHub {
      owner = "armbian";
      repo = "wifi-rtl8852bs";
      rev = "643a4990752ad4761c2ad216901257adfd4fd8db";
      hash = "sha256-jzLKuj/oBWUlzPM7fEfoGakMv+OIRWAlCvz5FvsWodc=";
    };
    nativeBuildInputs = atkKernel.moduleBuildDependencies;
    requiredSystemFeatures = [ "aarch64-cross" ];
    enableParallelBuilding = true;

    # Every platform switch in the driver Makefile defaults to "n"; selecting the
    # Rockchip platform is what turns on -DCONFIG_IOCTL_CFG80211 and
    # -DCONFIG_RADIO_WORK for the SDIO port.  CONFIG_RTW_DEBUG = n is the setting
    # Armbian patches in before building this driver.
    makeFlags = atkKernel.commonMakeFlags ++ [
      "KSRC=${atkKernel.dev}/lib/modules/${atkKernel.modDirVersion}/build"
      "CONFIG_PLATFORM_ARM_ROCKCHIP=y"
      "CONFIG_RTW_DEBUG=n"
      "INSTALL_MOD_PATH=${placeholder "out"}"
      "INSTALL_MOD_DIR=extra"
    ];

    # The kernel turns -Wdate-time into an error; rtw_debug.c stamps __DATE__ into
    # its version banner, which is otherwise harmless for a module.
    KCFLAGS = "-Wno-error=date-time";

    # NixOS stitches the per-module signing certificates into modules.cer, so the
    # module has to be installed through kbuild's own modules_install target, with
    # the kernel's flags (including its kmodigest signing command) spelled out.
    installPhase = ''
      runHook preInstall
      make ${
        lib.escapeShellArgs (
          atkKernel.commonMakeFlags
          ++ [
            "INSTALL_MOD_PATH=${placeholder "out"}"
            "INSTALL_MOD_DIR=extra"
          ]
        )
      } -C ${atkKernel.dev}/lib/modules/${atkKernel.modDirVersion}/build M=$PWD modules_install
      runHook postInstall
    '';

    dontStrip = true;
    meta = {
      description = "Vendor SDIO driver for the Realtek RTL8852BS";
      license = lib.licenses.gpl2Only;
      platforms = [ "aarch64-linux" ];
    };
  };

  # Mainline's rocket accel driver only knows the RK3588 NPU (the RK3568 support is
  # still an unmerged RFC), so the RKNN runtime needs the vendor rknpu driver, here
  # rebased onto mainline.  It drives the NPU without the IOMMU, see the board DTS.
  rknpu = crossPkgs.stdenv.mkDerivation {
    pname = "rknpu";
    version = "0.9.8-unstable-2026-04-28";
    src = pkgs.fetchFromGitHub {
      owner = "w568w";
      repo = "rknpu-module";
      rev = "a8792fe6b633f90cf2c6808267cac327537ab4cf";
      hash = "sha256-4pFs4tZR6Xy0e5wk8XDNJh8kpbhvWGLxH7KKU5wgWrk=";
    };
    nativeBuildInputs = atkKernel.moduleBuildDependencies;
    requiredSystemFeatures = [ "aarch64-cross" ];
    enableParallelBuilding = true;

    # The driver's own devfreq governor only exists from 6.19 on, where
    # devfreq-governor.h became a public header; on 6.18 the governor API is
    # still internal to drivers/devfreq.  Build without it, which leaves the NPU
    # on the clock rate the device tree assigns.
    KCFLAGS = "-DRKNPU_NO_DEVFREQ";
    postPatch = ''
      substituteInPlace Kbuild --replace-fail " src/rknpu_devfreq.o" ""
    '';

    # The Kbuild file defines the module; the wrapper Makefile only adds the
    # DKMS-style convenience targets, so the kernel build system is driven directly.
    makeFlags = atkKernel.commonMakeFlags ++ [
      "KDIR=${atkKernel.dev}/lib/modules/${atkKernel.modDirVersion}/build"
      "INSTALL_MOD_PATH=${placeholder "out"}"
      "INSTALL_MOD_DIR=extra"
    ];

    installPhase = ''
      runHook preInstall
      make ${
        lib.escapeShellArgs (
          atkKernel.commonMakeFlags
          ++ [
            "INSTALL_MOD_PATH=${placeholder "out"}"
            "INSTALL_MOD_DIR=extra"
          ]
        )
      } -C ${atkKernel.dev}/lib/modules/${atkKernel.modDirVersion}/build M=$PWD modules_install
      runHook postInstall
    '';

    dontStrip = true;
    meta = {
      description = "Vendor RKNPU driver for the RK3568 NPU, ported to mainline";
      license = lib.licenses.gpl2Only;
      platforms = [ "aarch64-linux" ];
    };
  };

  # The board is not in mainline yet, so it carries its own DTS derived from the
  # EVB1 reference design (PHY strapping, reset ownership, on-board RTC).
  atkDtb = pkgs.deviceTree.compileDTS {
    name = "rk3568-atk-dlrk3568.dtb";
    dtsFile = ./rk3568-atk-dlrk3568.dts;
    includePaths = [
      "${atkKernelSrc}/include"
      "${atkKernelSrc}/arch/arm64/boot/dts/rockchip"
    ];
  };

  atkDtbs = pkgs.runCommand "atk3568-dtbs" { } ''
    mkdir -p $out/rockchip
    cp ${atkDtb} $out/rockchip/rk3568-atk-dlrk3568.dtb
  '';
  ubootAtk3568 =
    (crossPkgs.ubootNanoPiR5S.override {
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
      "8852bs"
      "hci_uart"
      "rknpu"
      "rtc_pcf8563"
      "wireguard"
    ];
    extraModulePackages = lib.mkForce [
      rknpu
      rtl8852bs
    ];
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
  };

  hardware.deviceTree = {
    name = "rockchip/rk3568-atk-dlrk3568.dtb";
    filter = "rk3568-atk-dlrk3568.dtb";
    dtbSource = atkDtbs;
    overlays = [ ];
  };

  networking.networkmanager.enable = lib.mkForce false;

  # The module's 32.768 kHz low-power clock is fed by the RK809 (net
  # "RK809 32KOUT WIFI"). Mainline only enables CLK32KOUT2 when a clock consumer
  # asks for it, and nothing does on this board, so the Bluetooth core never
  # leaves reset and stays silent on its UART.
  systemd.services.atk3568-pmic-32k = {
    description = "Enable the RK809 32.768 kHz output for the RTL8852BS module";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-udevd.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      PrivateDevices = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      ExecStart = "${pkgs.i2c-tools}/bin/i2cset -y -f -m 0x01 0 0x20 0x20 0x01";
    };
  };

  # RTL8852BS Bluetooth hangs off UART8; the HCI only appears after the vendor
  # tool uploads firmware over H5, since mainline hci_uart has no RTL protocol.
  hardware.bluetooth = {
    enable = lib.mkForce true;
    powerOnBoot = true;
  };

  # The vendor tool only syncs over H5 right after a BT_REG_ON power cycle, and
  # it must keep REG_ON asserted afterwards, so the pulse and the hold live in
  # this unit's cgroup: stopping the unit releases the pin, a restart re-pulses.
  systemd.services.btattach-uart8 = {
    description = "Attach RTL8852BS Bluetooth HCI on UART8";
    wantedBy = [ "multi-user.target" ];
    after = [
      "dev-ttyS0.device"
      "atk3568-pmic-32k.service"
    ];
    wants = [ "atk3568-pmic-32k.service" ];
    bindsTo = [ "dev-ttyS0.device" ];
    serviceConfig = {
      Type = "simple";
      ExecStartPre = pkgs.writeShellScript "atk3568-bt-power-cycle" ''
        export PATH=${pkgs.libgpiod}/bin:$PATH
        gpioset -c gpiochip3 0=0 &
        holder=$!
        sleep 1
        kill "$holder"
        sleep 1
        gpioset -c gpiochip3 0=1 &
        sleep 1
      '';
      ExecStart = "${
        inputs.zhyi-packages.packages.${pkgs.stdenv.hostPlatform.system}.rtkbt
      }/bin/rtk_hciattach -n -s 115200 /dev/ttyS0 rtk_h5";
      Restart = "on-failure";
      RestartSec = "5s";
      PrivateDevices = lib.mkForce false;
      PrivateUsers = lib.mkForce false;
      BindPaths = [
        "/dev/ttyS0"
        "/dev/gpiochip3"
      ];
    };
  };

  lantian.harden.btattach-uart8.enable = "network";
  lantian.harden.atk3568-pmic-32k = {
    enable = true;
    enableConfinement = false;
  };

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
        "nosuid"
        "nodev"
        "noexec"
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
