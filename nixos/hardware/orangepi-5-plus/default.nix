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

  # Pin only gnull/nixos-rk3588's vendor-kernel packaging files here instead of
  # adding the whole repository as a Flake input. This remains an OPI5P-local
  # implementation detail and does not add its unrelated Flake dependencies to
  # the global lock graph.
  rk3588NixSource = crossPkgs.fetchFromGitHub {
    owner = "gnull";
    repo = "nixos-rk3588";
    rev = "2a1add82960dda2e0d203051dcf1ae4c1bc8452c";
    hash = "sha256-nHNgt6Kkn+rFrJW2vFDsTLd7DfYlZWQgCPyk67L2q/E=";
  };
  vendorKernelConfig = builtins.readFile (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config");
  vendorKernelConfigOptions = import (rk3588NixSource + "/pkgs/kernel/rk35xx_vendor_config.nix");
  opi5pKernelConfig =
    assert lib.hasInfix "# CONFIG_ARM64_VA_BITS_39 is not set" vendorKernelConfig;
    assert lib.hasInfix "CONFIG_ARM64_VA_BITS_48=y" vendorKernelConfig;
    assert lib.hasInfix "CONFIG_ARM64_VA_BITS=48" vendorKernelConfig;
    # MPTCP is built into the vendor kernel.  IPv6 must therefore be built in
    # as well: when IPv6 is a module, the MPTCP protocol registers before IPv6
    # exists and AF_INET6/SOCK_STREAM/IPPROTO_MPTCP remains unavailable.  The
    # author's nginx listener uses `multipath` for both address families.
    assert lib.hasInfix "CONFIG_IPV6=m" vendorKernelConfig;
    crossPkgs.writeText "rk35xx-vendor-opi5p-config" (
      builtins.replaceStrings
        [
          "# CONFIG_ARM64_VA_BITS_39 is not set"
          "CONFIG_ARM64_VA_BITS_48=y"
          "CONFIG_ARM64_VA_BITS=48"
          "CONFIG_IPV6=m"
        ]
        [
          "CONFIG_ARM64_VA_BITS_39=y"
          "# CONFIG_ARM64_VA_BITS_48 is not set"
          "CONFIG_ARM64_VA_BITS=39"
          "CONFIG_IPV6=y"
        ]
        vendorKernelConfig
    );
  opi5pKernel =
    (crossPkgs.linuxManualConfig {
      modDirVersion = "6.1.115";
      version = "6.1.115-armbian";
      extraMeta.branch = "rk-6.1-rkr5.1";
      src = crossPkgs.fetchFromGitHub {
        owner = "armbian";
        repo = "linux-rockchip";
        rev = "b908c7339f51eddcfe8402cd15d1e1f8f4e67c29";
        hash = "sha256-70wGP16SJHs7I8HklhNdrJbWzfvcgJCupgfOq81e1U8=";
      };
      kernelPatches = [ ];
      configfile = opi5pKernelConfig;
      config =
        builtins.removeAttrs vendorKernelConfigOptions [
          "CONFIG_ARM64_VA_BITS_48"
          "CONFIG_ARM64_VA_BITS"
        ]
        // {
          CONFIG_ARM64_VA_BITS_39 = "y";
          CONFIG_ARM64_VA_BITS = "9";
          CONFIG_IPV6 = "y";
        };
    }).overrideAttrs
      (old: {
        name = "k";
        nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ crossPkgs.ubootTools ];
        requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
        # Patch the board's vendor DTS before the kernel builds its DTB. Using
        # hardware.deviceTree.overlays here corrupts this non-mainline tree.
        patches = (old.patches or [ ]) ++ [ ./vendor-fan-curve.patch ];
        # Preserve gnull/nixos-rk3588's fix for the vendor driver's relative
        # CSF firmware include path in reproducible out-of-tree builds.
        postPatch = ''
          sed -i "drivers/gpu/arm/bifrost/csf/mali_kbase_csf_firmware.c" \
            -e "s:drivers/gpu/arm/bifrost/mali_csffw.bin:$src/drivers/gpu/arm/bifrost/mali_csffw.bin:"
        ''
        + "\n"
        + (old.postPatch or "");
      });

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
  # The vendor kernel, its DTB and the Orange Pi firmware form one hardware
  # support set. Keep the package pinned inside this host module, just like the
  # kernel, instead of substituting a hand-picked linux-firmware subset.
  opi5pFirmware = pkgs.callPackage (rk3588NixSource + "/pkgs/orangepi-firmware") { };
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
    initrd.kernelModules = lib.mkForce [ ];
    kernelModules = lib.mkForce [
      "dwmac_motorcomm"
      "r8169"
    ];
    # The generic out-of-tree modules use native ARM build tools and cannot
    # build against this x86_64 cross-built vendor kernel.
    extraModulePackages = lib.mkForce [ ];
    # Keep these after the repository-wide defaults. In particular, override
    # the common RCU-stall suppression while bringing this board up so a hard
    # lockup identifies the exact initcall instead of going silent.
    kernelParams = lib.mkAfter [
      # RK3588 UART2 is at 0xfeb50000 (different from RK3568's 0xfe660000).
      # Do NOT append baud rate after the MMIO address; doing so hides all
      # output after U-Boot's "Starting kernel ..." line.
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

  fileSystems."/run/nullfs".enable = lib.mkForce false;

  # Keep the author's kernel package wrapper so its custom module attributes
  # remain available on ARM, just as on lt-rpi4 and nanopi-r5c.
  lantian.kernel = lib.mkForce opi5pKernel;

  # This headless extlinux board never installs a GRUB theme.  Disable the
  # common theme units so their large source archive is absent from the image.
  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    # Upstream installs both Orange Pi's vendor bundle and Nixpkgs firmware;
    # the latter is also needed by add-on hardware such as the Intel AX200.
    enableRedistributableFirmware = lib.mkForce true;
    firmware = [ opi5pFirmware ];
    bluetooth.enable = true;
    wirelessRegulatoryDatabase = true;
  };

  hardware.deviceTree = {
    name = "rockchip/rk3588-orangepi-5-plus.dtb";
    filter = "rk3588-orangepi-5-plus.dtb";
    # Keep the vendor DTB intact. Applying a mainline-style fan overlay to this
    # vendor tree duplicates reserved-memory and SoC nodes, breaking PCIe, GPU,
    # NPU and other platform resources before userspace starts.
    overlays = [ ];
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

  # Red is a hardware power indicator. Configure the two software-controlled
  # LEDs as soon as their devices appear: blue shows kernel liveness and green
  # shows storage activity. RJ45 LEDs remain under PHY control.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="blue:indicator-1", ATTR{trigger}="heartbeat"
    ACTION=="add", SUBSYSTEM=="leds", KERNEL=="green:indicator-2", ATTR{trigger}="disk-activity"
  '';

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
      device = "/dev/disk/by-label/NVME_BOOT";
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

  # sdImage contains a deliberately small Btrfs /nix filesystem so that it can
  # be written to small cards.  This board uses tmpfs for /, therefore the
  # generic sdImage grow service cannot discover the persistent partition.
  # Expand the GPT partition and its mounted Btrfs filesystem once on the
  # target's first boot instead.  The guard makes later boots a no-op.
  systemd.services.opi5p-grow-nix = {
    description = "Expand Orange Pi 5 Plus persistent Nix filesystem";
    wantedBy = [ "multi-user.target" ];
    after = [ "nix.mount" ];
    requires = [ "nix.mount" ];
    before = [ "sops-install-secrets.service" "podman-redroid.service" ];
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

  # Match gnull/nixos-rk3588's Orange Pi 5 Plus boot contract: Armbian/vendor
  # U-Boot must already be installed in SPI NOR. This image deliberately does
  # not mix Nixpkgs' mainline U-Boot/ATF with the Armbian vendor kernel.
  # Keep the first 32 MiB free, as expected by the reference image layout.
  sdImage = {
    firmwarePartitionOffset = 32;
    firmwarePartitionName = "NVME_BOOT";
    firmwareSize = 256;
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
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

      # Armbian's vendor U-Boot 2017.09 on this board incorrectly selects its
      # EFI partition parser for the generic sd-image MBR and then refuses to
      # fall back to DOS partitions. Convert the finished image in place to a
      # valid GPT while preserving both partition starts and their contents.
      # This also avoids relying on stale GPT metadata left at the end of a
      # previously used SD card.
      # sd-image makes partition 2 end at the final sector. Reserve the 33
      # sectors required by GPT's backup header and partition-entry array.
      ${pkgs.buildPackages.coreutils}/bin/truncate --size=+16896 "$img"
      ${pkgs.buildPackages.gptfdisk}/bin/sgdisk --mbrtogpt "$img"
    '';
  };
}
