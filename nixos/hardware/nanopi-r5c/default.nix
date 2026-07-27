{
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}:
let
  # NanoPi R5C and R5S share the RK3568 boot layout; select the board-specific
  # upstream defconfig while retaining the Nixpkgs U-Boot package structure.
  ubootNanoPiR5C = pkgs.ubootNanoPiR5S.override {
    defconfig = "nanopi-r5c-rk3568_defconfig";
  };
  # Use Armbian's Rockchip 6.18 config as the platform baseline instead of
  # Nixpkgs' very broad arm64 config.  The baseline was checked against the
  # R5C/R5S DTS compatibles and the modules used by the running router.  NixOS
  # storage, networking, namespaces and firewall requirements remain enabled.
  r5cKernel = pkgs.linux_6_18.override {
    configfile = ./kernel-config;
    structuredExtraConfig = with lib.kernel; {
      # Expose all four RTL8125 PHY LED outputs through /sys/class/leds.
      # The R5C RJ45 jacks physically use two of them (green and yellow).
      R8169_LEDS = yes;
    };
  };
  # The installed MT7921 requests only these six blobs.  Copy their contents
  # instead of retaining the complete linux-firmware package (roughly 800 MiB)
  # in every R5C system closure.
  mt7921Firmware = pkgs.runCommand "mt7921-firmware" { } ''
    source=${pkgs.linux-firmware}/lib/firmware/mediatek
    destination=$out/lib/firmware/mediatek
    mkdir -p "$destination"
    for firmware in \
      WIFI_MT7922_patch_mcu_1_1_hdr.bin \
      WIFI_RAM_CODE_MT7922_1.bin \
      WIFI_MT7961_patch_mcu_1_2_hdr.bin \
      WIFI_RAM_CODE_MT7961_1.bin \
      WIFI_MT7961_patch_mcu_1a_2_hdr.bin \
      WIFI_RAM_CODE_MT7961_1a.bin
    do
      test -e "$source/$firmware"
      cp -L "$source/$firmware" "$destination/$firmware"
    done
  '';
  savedClock = "/nix/persistent/var/lib/r5c-clock/epoch";
  saveClock = pkgs.writeShellScript "r5c-save-clock" ''
    install -d -m 0700 "$(dirname ${savedClock})"
    date +%s > ${savedClock}.new
    chmod 0600 ${savedClock}.new
    mv ${savedClock}.new ${savedClock}
  '';
  restoreClock = pkgs.writeShellScript "r5c-restore-clock" ''
    if test -s ${savedClock}; then
      date --utc --set="@$(cat ${savedClock})"
    fi
  '';
  configureLeds = pkgs.writeShellScript "r5c-configure-leds" ''
    set_trigger() {
      local led=$1
      local trigger=$2
      local trigger_file="/sys/class/leds/$led/trigger"

      if test -w "$trigger_file" && grep -qw "$trigger" "$trigger_file"; then
        echo "$trigger" > "$trigger_file"
      fi
    }

    set_netdev_trigger() {
      local led=$1
      local device=$2
      local led_path="/sys/class/leds/$led"

      if test -e "/sys/class/net/$device" \
        && test -w "$led_path/trigger" \
        && grep -qw "netdev" "$led_path/trigger"; then
        echo "netdev" > "$led_path/trigger"
        echo "$device" > "$led_path/device_name"
        echo 1 > "$led_path/link"
        echo 1 > "$led_path/rx"
        echo 1 > "$led_path/tx"
        echo 50 > "$led_path/interval"
      fi
    }

    set_trigger "red:power" "heartbeat"
    # Keep each green LED lit while its interface has carrier and flash it for
    # both receive and transmit activity, like a disk activity indicator.
    set_netdev_trigger "green:lan" "eth0"
    set_netdev_trigger "green:wan" "eth1"
    set_netdev_trigger "green:wlan" "wlan0"
  '';
in
{
  imports = [
    (modulesPath + "/profiles/base.nix")
    (modulesPath + "/installer/sd-card/sd-image.nix")
  ];

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  boot = {
    # MMC, NVMe and the RK3568 storage controllers are builtin in the trimmed
    # Rockchip config.  Keep only the modular network driver in this list;
    # Btrfs is pulled into the initrd through supportedFilesystems below.
    initrd.availableKernelModules = [ "r8169" ];
    initrd.kernelModules = [ "r8169" ];
    kernelModules = [
      "ledtrig_netdev"
      "r8169"
    ];
    kernelParams = [
      # The uart8250 earlycon parser must not be given the baud rate here; doing
      # so hides all output after U-Boot's "Starting kernel ..." line.
      # The board-specific sd-image imports below deliberately avoid the generic
      # aarch64 image's ttyS0/ttyAMA0 parameters, leaving ttyS2 as the only
      # serial console so the real 8250 driver can replace earlycon cleanly.
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
        # Two complete generations fit in the 256 MiB FAT partition.  The
        # repository-wide default of 20 eventually fills /boot on this board.
        configurationLimit = lib.mkForce 2;
      };
      grub = {
        enable = lib.mkForce false;
        extraInstallCommands = lib.mkForce "";
      };
    };
  };

  # Keep the author's kernel package wrapper so its custom module attributes
  # remain available on ARM, just as on lt-rpi4.
  lantian.kernel = lib.mkForce r5cKernel;

  # This headless extlinux board has no GRUB theme directory.  Disable both the
  # theme module and the common installer service so their large source archive
  # is not retained by the system closure.
  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    enableRedistributableFirmware = lib.mkForce false;
    firmware = [ mt7921Firmware ];
  };

  hardware.deviceTree = {
    name = "rockchip/rk3568-nanopi-r5c.dtb";
    # Follow lt-rpi4: only copy DTBs for the target board into /boot.
    filter = "rk3568-nanopi-r5c.dtb";
  };

  # RK3568 boards may return to a firmware timestamp after losing power.  Keep
  # a coarse clock on persistent storage so TLS works while ntpd-rs gathers
  # enough agreeing sources to perform its precise startup correction.
  systemd = {
    services = {
      r5c-restore-clock = {
        description = "Restore NanoPi R5C software clock";
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
      r5c-save-clock = {
        description = "Save NanoPi R5C software clock";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = saveClock;
        };
      };
      r5c-leds = {
        description = "Configure NanoPi R5C status LEDs";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        path = [
          pkgs.coreutils
          pkgs.gnugrep
        ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = configureLeds;
        };
      };
    };
    timers.r5c-save-clock = {
      description = "Periodically save NanoPi R5C software clock";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
        Unit = "r5c-save-clock.service";
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

  # Keep the first partition beyond both Rockchip bootloader payloads:
  # idbloader.img at 32 KiB and u-boot.itb at 8 MiB.
  sdImage = {
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ./make-nix-btrfs-fs.nix;
    rootPartitionUUID = "44444444-4444-4444-8888-888888888888";
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
      dd if=${ubootNanoPiR5C}/idbloader.img of="$img" seek=64 conv=notrunc status=none
      dd if=${ubootNanoPiR5C}/u-boot.itb of="$img" seek=16384 conv=notrunc status=none
    '';
  };
}
