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

  # Start from the repository's already validated RK356x kernel baseline.  It
  # keeps the Rockchip clock, pinctrl, PM-domain, RK809 regulator, SD/MMC,
  # DesignWare Ethernet, USB and serial drivers built in, while avoiding the
  # generic arm64 configuration's unrelated GPU, media, wireless and joystick
  # families.  LubanCat-specific changes can move to a separate config after
  # the first hardware inventory; until then, sharing the R5C config also lets
  # the binary cache reuse the exact same cross-built kernel derivation.
  lubanCatKernelConfigText =
    builtins.replaceStrings
      [
        "# CONFIG_WLAN_VENDOR_REALTEK is not set"
        "CONFIG_ZRAM=m"
      ]
      [
        ''
          CONFIG_WLAN_VENDOR_REALTEK=y
          CONFIG_RTW88=m
          CONFIG_RTW88_CORE=m
          CONFIG_RTW88_PCI=m
          CONFIG_RTW88_8822C=m
          CONFIG_RTW88_8822CE=m
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
  lubanCatKernelConfig = builtins.toFile "lubancat1-kernel-config" lubanCatKernelConfigText;

  # linuxManualConfig automatically parses a literal Nix path, but
  # builtins.toFile returns a store-path string. Parse the generated text with
  # the same y/m rule as Nixpkgs so CONFIG_MODULES=y creates the real `modules`
  # output instead of silently treating this as a monolithic kernel.
  lubanCatKernelConfigAttrs = lib.listToAttrs (
    lib.concatMap (
      line:
      let
        match = builtins.match "(CONFIG_[^=]+)=([ym])" line;
      in
      lib.optional (match != null) {
        name = builtins.elemAt match 0;
        value = builtins.elemAt match 1;
      }
    ) (lib.splitString "\n" lubanCatKernelConfigText)
  );

  # The kernel builder already requires `big-parallel`, which this repository
  # advertises only on ml-builder. Do not add a redundant scheduler override.
  lubanCatKernel = crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_6_18) src version modDirVersion;
    configfile = lubanCatKernelConfig;
    config = lubanCatKernelConfigAttrs;
  };

  # The installed Mini PCIe card is an RTL8822CE. Its Bluetooth USB function
  # identifies as RTL8822CU. Copy only the matching Wi-Fi/Bluetooth firmware;
  # retaining the complete linux-firmware package would dominate this 2 GiB
  # board's deliberately small closure.
  rtl8822Firmware = crossPkgs.buildPackages.runCommand "lubancat1-rtl8822-firmware" {
    requiredSystemFeatures = [ "aarch64-cross" ];
  } ''
    # linux-firmware contains no target binaries; reuse the target package
    # already present in the image build while executing this copy on x86_64.
    source=${pkgs.linux-firmware}/lib/firmware
    mkdir -p "$out/lib/firmware/rtw88" "$out/lib/firmware/rtl_bt"
    cp -L "$source/rtw88/rtw8822c_fw.bin" "$out/lib/firmware/rtw88/"
    cp -L "$source/rtw88/rtw8822c_wow_fw.bin" "$out/lib/firmware/rtw88/"
    cp -L "$source/rtl_bt/rtl8822cu_fw.bin" "$out/lib/firmware/rtl_bt/"
    if test -e "$source/rtl_bt/rtl8822cu_config.bin"; then
      cp -L "$source/rtl_bt/rtl8822cu_config.bin" "$out/lib/firmware/rtl_bt/"
    fi
  '';

  # Mainline U-Boot has no LubanCat-1 defconfig. Its generic RK3568 target is
  # intentionally board-neutral and uses the same RK3566/RK3568 TPL and BL31
  # boot chain as Nixpkgs' Orange Pi 3B package. Linux later receives the exact
  # rk3566-lubancat-1 DTB from extlinux.
  ubootLubanCat1 = (crossPkgs.ubootOrangePi3B.override {
    defconfig = "generic-rk3568_defconfig";
  }).overrideAttrs (old: {
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
  });

  # The board has no battery-backed RTC. Preserve a recent epoch on the
  # persistent filesystem so TLS, SOPS logs and service ordering do not start
  # from the firmware's 2017 timestamp after every complete power loss.
  savedClock = "/nix/persistent/var/lib/lubancat1-clock/epoch";
  saveClock = pkgs.writeShellScript "lubancat1-save-clock" ''
    install -d -m 0700 "$(dirname ${savedClock})"
    date +%s > ${savedClock}.new
    chmod 0600 ${savedClock}.new
    mv ${savedClock}.new ${savedClock}
  '';
  restoreClock = pkgs.writeShellScript "lubancat1-restore-clock" ''
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

  # Linux 6.18 already contains the original, non-V2 LubanCat-1 DTS.  Keep the
  # repository's kernel package wrapper around the targeted RK356x build.
  lantian.kernel = lib.mkForce lubanCatKernel;

  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    enableRedistributableFirmware = lib.mkForce false;
    firmware = [ rtl8822Firmware ];
    wirelessRegulatoryDatabase = true;
    bluetooth.enable = true;
  };

  hardware.deviceTree = {
    name = "rockchip/rk3566-lubancat-1.dtb";
    filter = "rk3566-lubancat-1.dtb";
  };

  systemd = {
    services = {
      lubancat1-restore-clock = {
        description = "Restore LubanCat-1 software clock";
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
      lubancat1-save-clock = {
        description = "Save LubanCat-1 software clock";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = saveClock;
        };
      };
    };
    timers.lubancat1-save-clock = {
      description = "Periodically save LubanCat-1 software clock";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
        Unit = "lubancat1-save-clock.service";
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

  # The image contains a compact Btrfs filesystem and tmpfs `/`, so Nixpkgs'
  # generic root-partition grow service cannot discover the persistent store.
  # Grow partition 2 and /nix once after a fresh image is written. Repeated
  # runs are harmless and only resize the filesystem to its existing maximum.
  systemd.services.lubancat1-grow-nix = {
    description = "Expand LubanCat-1 persistent Nix filesystem";
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
      dd if=${ubootLubanCat1}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootLubanCat1}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
