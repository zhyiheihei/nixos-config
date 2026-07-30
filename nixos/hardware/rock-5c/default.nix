{
  config,
  lib,
  modulesPath,
  pkgs,
  self,
  ...
}:
let
  # Build ARM artifacts with a native x86_64 cross toolchain. Running the ARM
  # compiler itself through qemu-user makes kernel and U-Boot builds needlessly
  # slow on ml-builder.
  crossPkgs = self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform;

  rk3588NixSource = crossPkgs.fetchFromGitHub {
    owner = "gnull";
    repo = "nixos-rk3588";
    rev = "2a1add82960dda2e0d203051dcf1ae4c1bc8452c";
    hash = "sha256-nHNgt6Kkn+rFrJW2vFDsTLd7DfYlZWQgCPyk67L2q/E=";
  };
  vendorKernelConfig = builtins.readFile (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config");
  vendorKernelConfigOptions = import (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config.nix");
  rock5cKernelConfig =
    assert lib.hasInfix "# CONFIG_ARM64_VA_BITS_39 is not set" vendorKernelConfig;
    assert lib.hasInfix "CONFIG_ARM64_VA_BITS_48=y" vendorKernelConfig;
    assert lib.hasInfix "CONFIG_ARM64_VA_BITS=48" vendorKernelConfig;
    crossPkgs.writeText "rk35xx-vendor-rock5c-config" (
      builtins.replaceStrings
        [
          "# CONFIG_ARM64_VA_BITS_39 is not set"
          "CONFIG_ARM64_VA_BITS_48=y"
          "CONFIG_ARM64_VA_BITS=48"
        ]
        [
          "CONFIG_ARM64_VA_BITS_39=y"
          "# CONFIG_ARM64_VA_BITS_48 is not set"
          "CONFIG_ARM64_VA_BITS=39"
        ]
        vendorKernelConfig
    );
  rock5cKernel = (
    (crossPkgs.callPackage (rk3588NixSource + "/pkgs/kernel/vendor.nix") { }).override {
      configfile = rock5cKernelConfig;
      config =
        builtins.removeAttrs vendorKernelConfigOptions [
          "CONFIG_ARM64_VA_BITS_48"
          "CONFIG_ARM64_VA_BITS"
        ]
        // {
          CONFIG_ARM64_VA_BITS_39 = "y";
          CONFIG_ARM64_VA_BITS = "9";
        };
    }
  ).overrideAttrs (old: {
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
  });

  # ROCK 5C has no populated SPI NOR. Build upstream U-Boot and place both
  # Rockchip boot stages in the unused area before partition 1.
  rock5cUBoot = (
    crossPkgs.buildUBoot {
      defconfig = "rock-5c-rk3588s_defconfig";
      BL31 = "${crossPkgs.armTrustedFirmwareRK3588}/bl31.elf";
      ROCKCHIP_TPL = crossPkgs.rkbin.TPL_RK3588;
      filesToInstall = [
        "idbloader.img"
        "u-boot.itb"
      ];
      extraMeta.platforms = [ "aarch64-linux" ];
    }
  ).overrideAttrs (old: {
    requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
  });

  savedClock = "/nix/persistent/var/lib/rock5c-clock/epoch";
  saveClock = pkgs.writeShellScript "rock5c-save-clock" ''
    install -d -m 0700 "$(dirname ${savedClock})"
    date +%s > ${savedClock}.new
    chmod 0600 ${savedClock}.new
    mv ${savedClock}.new ${savedClock}
  '';
  restoreClock = pkgs.writeShellScript "rock5c-restore-clock" ''
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
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = [ ];
    kernelModules = [ "dwmac_rk" ];
    kernelParams = lib.mkAfter [
      "earlycon=uart8250,mmio32,0xfeb50000"
      "console=ttyS2,1500000n8"
      "console=tty0"
      "rootwait"
      "rcuupdate.rcu_cpu_stall_suppress=0"
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

  lantian.kernel = lib.mkForce rock5cKernel;
  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    enableRedistributableFirmware = lib.mkForce true;
    bluetooth.enable = true;
    wirelessRegulatoryDatabase = true;
  };
  hardware.deviceTree = {
    name = "rockchip/rk3588s-rock-5c.dtb";
    filter = "rk3588s-rock-5c.dtb";
    overlays = [ ];
  };

  systemd = {
    services = {
      rock5c-restore-clock = {
        description = "Restore ROCK 5C software clock";
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
      rock5c-save-clock = {
        description = "Save ROCK 5C software clock";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = saveClock;
        };
      };
      rock5c-grow-nix = {
        description = "Expand ROCK 5C persistent Nix filesystem";
        wantedBy = [ "multi-user.target" ];
        after = [ "nix.mount" ];
        requires = [ "nix.mount" ];
        before = [ "sops-install-secrets.service" "podman-redroid.service" ];
        path = [
          pkgs.btrfs-progs
          pkgs.coreutils
          pkgs.gptfdisk
          pkgs.gnugrep
          pkgs.gnused
          pkgs.parted
          pkgs.util-linux
        ];
        script = ''
          partition_device=$(findmnt -n -o SOURCE /nix)
          disk="/dev/$(lsblk -n -o PKNAME "$partition_device")"
          partition=$(lsblk -n -o PARTN "$partition_device")

          test -b "$disk"
          test -n "$partition"
          current_end=$(sgdisk -i "$partition" "$disk" | sed -n 's/^Last sector: \([0-9][0-9]*\).*/\1/p')
          usable_end=$(sgdisk -p "$disk" | sed -n 's/^First usable sector is [0-9][0-9]*, last usable sector is \([0-9][0-9]*\).*/\1/p')

          if [ "$current_end" -lt "$usable_end" ]; then
            sgdisk -e "$disk"
            printf 'Yes\\n' | parted ---pretend-input-tty "$disk" resizepart "$partition" 100%
            partx -u "$disk"
          fi
          btrfs filesystem resize max /nix
        '';
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
      };
    };
    timers.rock5c-save-clock = {
      description = "Periodically save ROCK 5C software clock";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
        Unit = "rock5c-save-clock.service";
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

  sdImage = {
    # idbloader (32 KiB) and U-Boot proper (8 MiB) both fit below this.
    firmwarePartitionOffset = 32;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
    rootPartitionUUID = "55555555-5555-5555-9999-999999999999";
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

      ${pkgs.buildPackages.coreutils}/bin/dd \
        if=${rock5cUBoot}/idbloader.img of="$img" bs=512 seek=64 conv=notrunc
      ${pkgs.buildPackages.coreutils}/bin/dd \
        if=${rock5cUBoot}/u-boot.itb of="$img" bs=512 seek=16384 conv=notrunc

      ${pkgs.buildPackages.coreutils}/bin/truncate --size=+16896 "$img"
      ${pkgs.buildPackages.gptfdisk}/bin/sgdisk --mbrtogpt "$img"
    '';
  };
}
