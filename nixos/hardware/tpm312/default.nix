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

  # TPM312-MAIN-V1.1 is a Rockchip RK3399 advertising mainboard: RK808 PMIC,
  # LPDDR4, 16 GB eMMC on sdhci, one RTL8211F gigabit PHY on GMAC and UART2 as
  # the debug console. The board is not in mainline; the DTS is the iStoreOS
  # source DTS, which targets the merged rk3399.dtsi of kernel 7.2 and later
  # (the separate rk3399-opp.dtsi no longer exists there).
  tpm312KernelSrc = pkgs.runCommand "linux-dts-tree" { nativeBuildInputs = [ pkgs.xz ]; } ''
    mkdir -p $out
    tar -xJf ${crossPkgs.linux_7_2.src} -C $out --strip-components=1 \
      linux-*/include \
      linux-*/arch/arm64/boot/dts/rockchip \
      linux-*/scripts/dtc/include-prefixes
  '';

  tpm312Kernel = crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_7_2) src version modDirVersion;
    configfile = ../nanopi-r5c/kernel-config;
  };

  # The board DTS is carried outside the kernel tree so bring-up iterations
  # only recompile the 66 KiB blob instead of rebuilding the kernel.
  tpm312Dtb = pkgs.deviceTree.compileDTS {
    name = "rk3399-tpm312.dtb";
    dtsFile = ./rk3399-tpm312.dts;
    includePaths = [
      "${tpm312KernelSrc}/include"
      "${tpm312KernelSrc}/arch/arm64/boot/dts/rockchip"
    ];
  };

  tpm312Dtbs = pkgs.runCommand "tpm312-dtbs" { } ''
    mkdir -p $out/rockchip
    cp ${tpm312Dtb} $out/rockchip/rk3399-tpm312.dtb
  '';

  # RK3399 has full mainline U-Boot support; only the board DTS is missing, so
  # the stock EVB target is reused. BL31 comes from the upstream ARM Trusted
  # Firmware build, not from the Rockchip rkbin blobs: rk3399 SPL initialises
  # LPDDR4 on its own, so no DDR blob is involved either.
  ubootTpm312 = (crossPkgs.ubootRockPro64.override {
    defconfig = "evb-rk3399_defconfig";
    extraConfig = ''
      CONFIG_DEFAULT_DEVICE_TREE="rockchip/rk3399-tpm312"
      CONFIG_DEFAULT_FDT_FILE="rockchip/rk3399-tpm312.dtb"
    '';
  }).overrideAttrs
    (old: {
      requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
      postPatch = (old.postPatch or "") + ''
        install -D -m 0644 ${./rk3399-tpm312.dts} \
          dts/upstream/src/arm64/rockchip/rk3399-tpm312.dts
      '';
    });

  # The board has no RTC battery path, so the clock is restored at boot from an
  # epoch saved on the persistent filesystem until NTP corrects it.
  savedClock = "/nix/persistent/var/lib/tpm312-clock/epoch";
  saveClock = pkgs.writeShellScript "tpm312-save-clock" ''
    install -d -m 0700 "$(dirname ${savedClock})"
    date +%s > ${savedClock}.new
    chmod 0600 ${savedClock}.new
    mv ${savedClock}.new ${savedClock}
  '';
  restoreClock = pkgs.writeShellScript "tpm312-restore-clock" ''
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
    # The RK3399 storage, serial, PMIC and Ethernet drivers are built into the
    # rockchip kernel config; keep the shrunk initrd free of unrelated modules.
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = lib.mkForce [ ];
    kernelModules = lib.mkForce [ "wireguard" ];
    extraModulePackages = lib.mkForce [ ];
    # ttyS2 must stay the last console= so /dev/console lands on the debug UART.
    kernelParams = [
      "earlycon=uart8250,mmio32,0xff1a0000"
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

  lantian.kernel = lib.mkForce tpm312Kernel;

  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    # Nothing on a headless RK3399 board needs redistributable firmware: the
    # PHY is driven by dwmac/stmmac and the eMMC by dw_mmc.
    enableRedistributableFirmware = lib.mkForce false;
    firmware = lib.mkForce [ ];
  };

  hardware.deviceTree = {
    name = "rockchip/rk3399-tpm312.dtb";
    filter = "rk3399-tpm312.dtb";
    dtbSource = tpm312Dtbs;
    overlays = [ ];
  };

  networking.networkmanager.enable = lib.mkForce false;

  systemd.services.tpm312-restore-clock = {
    description = "Restore TPM312 software clock";
    wantedBy = [ "sysinit.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = restoreClock;
    };
  };
  systemd.timers.tpm312-save-clock = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Unit = "tpm312-save-clock.service";
    };
  };
  systemd.services.tpm312-save-clock = {
    description = "Periodically save TPM312 software clock";
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

  # The image ships a compact Btrfs store and tmpfs `/`, so Nixpkgs' generic
  # root growth service cannot find the persistent partition; grow it explicitly.
  systemd.services.tpm312-grow-nix = {
    description = "Expand TPM312 persistent Nix filesystem";
    wantedBy = [ "multi-user.target" ];
    after = [ "nix.mount" ];
    requires = [ "nix.mount" ];
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
    # Reserve the standard Rockchip loader regions before the first partition:
    # idbloader at 32 KiB and U-Boot proper at 8 MiB.
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
    rootPartitionUUID = "0d4b6d0a-3f2f-4b0e-9b7e-6c1f4ed2b8a5";
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
      dd if=${ubootTpm312}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootTpm312}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
