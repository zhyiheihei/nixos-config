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

  # Start from the repository's already validated RK356x kernel baseline (the
  # same config used by LubanCat-1 and NanoPi R5C).  Taishan Pi specific
  # additions:
  #  - CONFIG_DRM_PANEL_SITRONIX_ST7701 for the 3.1-inch MIPI panel
  #  - CONFIG_RTW88 + CONFIG_RTW88_USB for the USB Wi-Fi adapter
  #  - CONFIG_PWM_ROCKCHIP for the backlight PWM
  taishanPiKernelConfigText =
    builtins.replaceStrings
      [
        "# CONFIG_DRM_PANEL_SITRONIX_ST7701 is not set"
        "# CONFIG_WLAN_VENDOR_REALTEK is not set"
        "CONFIG_ZRAM=m"
      ]
      [
        ''
          CONFIG_DRM_PANEL_SITRONIX_ST7701=y
        ''
        ''
          CONFIG_WLAN_VENDOR_REALTEK=y
          CONFIG_RTW88=m
          CONFIG_RTW88_CORE=m
          CONFIG_RTW88_USB=m
          # CONFIG_RTW88_DEBUG is not set
          # CONFIG_RTW88_DEBUGFS is not set
          CONFIG_RTW88_LEDS=y
        ''
        ''
          CONFIG_ZRAM=m
          CONFIG_ZRAM_BACKEND_ZSTD=y
          CONFIG_ZRAM_BACKEND_LZO=y
          # CONFIG_ZRAM_DEF_COMP_LZORLE is not set
          CONFIG_ZRAM_DEF_COMP_ZSTD=y
          CONFIG_ZRAM_DEF_COMP="zstd"
        ''
      ]
      (builtins.readFile ../nanopi-r5c/kernel-config);
  taishanPiKernelConfig = builtins.toFile "taishanpi-kernel-config" taishanPiKernelConfigText;

  # linuxManualConfig automatically parses a literal Nix path, but
  # builtins.toFile returns a store-path string. Parse the generated text with
  # the same y/m rule as Nixpkgs so CONFIG_MODULES=y creates the real `modules`
  # output instead of silently treating this as a monolithic kernel.
  taishanPiKernelConfigAttrs = lib.listToAttrs (
    lib.concatMap (
      line:
      let
        match = builtins.match "(CONFIG_[^=]+)=([ym])" line;
      in
      lib.optional (match != null) {
        name = builtins.elemAt match 0;
        value = builtins.elemAt match 1;
      }
    ) (lib.splitString "\n" taishanPiKernelConfigText)
  );

  # Linux 6.18 contains the mainline rk3566-lckfb-tspi DTS.  Add the 3.1-inch
  # ST7701 panel support (driver patch) and the DSI overlay that wires the
  # panel to VP1.  The kernel builder already requires `big-parallel`, which
  # this repository advertises only on ml-builder.
  taishanPiKernel = (crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_6_18) src version modDirVersion;
    configfile = taishanPiKernelConfig;
    config = taishanPiKernelConfigAttrs;
  }).overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../../pkgs/taishanpi-kernel/st7701-panel-lckfb-31inch.patch ];
  });

  # Mainline U-Boot has no Taishan Pi defconfig; the generic RK3568 target
  # boots the same TPL/BL31 chain as Orange Pi 3B. Linux later receives the
  # mainline rk3566-lckfb-tspi DTB from extlinux (with the DSI overlay applied).
  ubootTaishanPi = (crossPkgs.ubootOrangePi3B.override {
    defconfig = "generic-rk3568_defconfig";
  }).overrideAttrs (old: {
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
  });

  # The board has no battery-backed RTC. Preserve a recent epoch on the
  # persistent filesystem so TLS, SOPS logs and service ordering do not start
  # from the firmware timestamp after every complete power loss.
  savedClock = "/nix/persistent/var/lib/taishanpi-clock/epoch";
  saveClock = pkgs.writeShellScript "taishanpi-save-clock" ''
    install -d -m 0700 "$(dirname ${savedClock})"
    date +%s > ${savedClock}.new
    chmod 0600 ${savedClock}.new
    mv ${savedClock}.new ${savedClock}
  '';
  restoreClock = pkgs.writeShellScript "taishanpi-restore-clock" ''
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
    # RK3566 storage, serial, PMIC and USB drivers are built into the generic
    # arm64 kernel. Avoid importing unrelated x86 root modules into the shrunk
    # initrd.
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

  # The repository-wide kernel wrapper around the targeted RK356x build.
  lantian.kernel = lib.mkForce taishanPiKernel;

  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    enableRedistributableFirmware = lib.mkForce false;
    # The USB Wi-Fi adapter needs no extra firmware (rtw88 firmware is part of
    # the kernel package via linux-firmware unless trimmed elsewhere).
    firmware = lib.mkForce [ ];
    wirelessRegulatoryDatabase = true;
    # Taishan Pi has no onboard wired Ethernet; only Wi-Fi is available.
    bluetooth.enable = false;
  };

  hardware.deviceTree = {
    name = "rockchip/rk3566-lckfb-tspi.dtb";
    filter = "rk3566-lckfb-tspi.dtb";
    # Apply the 3.1-inch MIPI DSI panel overlay on top of the mainline DTB.
    # NixOS compiles dtsFile into a dtbo; a bare path would be treated as a
    # prebuilt dtbo and fail with FDT_ERR_BADMAGIC.
    overlays = [
      {
        name = "taishanpi-dsi31";
        dtsFile = ../../../pkgs/taishanpi-kernel/rk3566-taishanpi-dsi31-overlay.dts;
      }
    ];
  };

  # No wired NIC: bring up Wi-Fi through networkmanager-free systemd-networkd.
  # The USB adapter shows up as wlan0 via rtw88_usb. DHCP on wlan0 only.
  systemd.network.networks."10-taishanpi-wlan" = {
    matchConfig.Name = "wlan0";
    networkConfig = {
      DHCP = "ipv4";
      IPv6AcceptRA = true;
    };
  };

  networking.networkmanager.enable = lib.mkForce false;

  systemd.services.taishanpi-restore-clock = {
    description = "Restore Taishan Pi software clock";
    wantedBy = [ "sysinit.target" ];
    before = [ "systemd-tmpfiles-setup.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = restoreClock;
    };
  };
  systemd.timers.taishanpi-save-clock = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "5min";
      OnUnitActiveSec = "1h";
      Unit = "taishanpi-save-clock.service";
    };
  };
  systemd.services.taishanpi-save-clock = {
    description = "Periodically save Taishan Pi software clock";
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

  # The image contains a compact Btrfs filesystem and tmpfs `/`, so Nixpkgs'
  # generic root-partition grow service cannot discover the persistent store.
  systemd.services.taishanpi-grow-nix = {
    description = "Expand Taishan Pi persistent Nix filesystem";
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
      dd if=${ubootTaishanPi}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootTaishanPi}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
