{
  config,
  lib,
  modulesPath,
  pkgs,
  self,
  ...
}:
let
  # The host configuration is evaluated with native aarch64 packages.  On an
  # x86_64 builder that makes Nix execute the complete ARM64 GCC toolchain
  # through qemu-user.  Build the large kernel derivation with a real cross
  # toolchain instead: compiler processes run natively on x86_64 and emit
  # aarch64 objects.  The resulting kernel still has aarch64-linux as its host
  # platform and can be used by the otherwise unchanged system closure.
  crossPkgs =
    self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform;

  # NanoPi R5C and R5S share the RK3568 boot layout; select the board-specific
  # upstream defconfig while retaining the Nixpkgs U-Boot package structure.
  ubootNanoPiR5C = pkgs.ubootNanoPiR5S.override {
    defconfig = "nanopi-r5c-rk3568_defconfig";
  };
  # Build the upstream kernel with the resolved Rockchip configuration
  # directly.  Feeding a complete .config through generic.nix's question
  # generator is lossy for selected/hidden symbols; linuxManualConfig preserves
  # the olddefconfig result and still provides out/dev/modules outputs.
  r5cKernel = crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_6_18) src version modDirVersion;
    configfile = ./kernel-config;
    requiredSystemFeatures = [ "aarch64-cross" ];
  };
  # Keep only the firmware requested by the installed MT7921/BT adapter and
  # RTL8125 NICs instead of retaining the complete linux-firmware package
  # (roughly 800 MiB) in every R5C system closure.
  mt7921Firmware = pkgs.runCommand "mt7921-firmware" { } ''
    source=${pkgs.linux-firmware}/lib/firmware
    mkdir -p "$out/lib/firmware/mediatek" "$out/lib/firmware/rtl_nic"
    for firmware in \
      WIFI_MT7922_patch_mcu_1_1_hdr.bin \
      WIFI_RAM_CODE_MT7922_1.bin \
      WIFI_MT7961_patch_mcu_1_2_hdr.bin \
      WIFI_RAM_CODE_MT7961_1.bin \
      WIFI_MT7961_patch_mcu_1a_2_hdr.bin \
      WIFI_RAM_CODE_MT7961_1a.bin \
      BT_RAM_CODE_MT7961_1_2_hdr.bin
    do
      test -e "$source/mediatek/$firmware"
      cp -L "$source/mediatek/$firmware" "$out/lib/firmware/mediatek/$firmware"
    done
    cp -L "$source/rtl_nic/rtl8125b-2.fw" "$out/lib/firmware/rtl_nic/"
  '';
  # The RK3568 has no built-in RTC.  The RK808 PMIC RTC (rtc0) retains time
  # for short power cycles via a capacitor but resets on long power loss.
  # Sync from it at boot, write to it periodically, and let ntpd-rs do the
  # precise correction after the WAN comes up.
  hwclock = "${pkgs.util-linux}/bin/hwclock";
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

    # The heartbeat trigger does not drive brightness on this board's
    # red:power LED; use default-on so the power indicator stays lit.
    set_trigger "red:power" "default-on"
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
    # Match Armbian's NanoPi R5C support and use the in-tree r8169 driver for
    # both RTL8125 NICs.  The vendor r8125 module has repeatedly stalled its TX
    # queue under router traffic (NETDEV WATCHDOG), taking PPPoE down with it.
    initrd.availableKernelModules = lib.mkForce [ ];
    initrd.kernelModules = lib.mkForce [ ];
    kernelModules = lib.mkForce [
      "ledtrig_netdev"
      "r8169"
      "rtc_rk808"
    ];
    # The generic out-of-tree modules use native ARM build tools and cannot
    # build against this x86_64 cross-built kernel. Use in-tree drivers here.
    extraModulePackages = lib.mkForce [ ];
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

  fileSystems."/run/nullfs".enable = lib.mkForce false;

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
    # The MT7921 combo card provides both WiFi and Bluetooth.  Kernel modules
    # (btusb, bluetooth) load automatically; this starts bluetoothd so the
    # adapter is usable for BLE mesh, smart-home gateways, etc.
    bluetooth.enable = true;
  };

  hardware.deviceTree = {
    name = "rockchip/rk3568-nanopi-r5c.dtb";
    # Follow lt-rpi4: only copy DTBs for the target board into /boot.
    filter = "rk3568-nanopi-r5c.dtb";
  };

  # Sync system clock from the hardware RTC at boot, and write it back
  # periodically so the RTC stays current for the next cold start.
  systemd = {
    services = {
      r5c-hwclock-restore = {
        description = "Restore system clock from hardware RTC";
        wantedBy = [ "multi-user.target" ];
        after = [ "systemd-modules-load.service" ];
        before = [ "ntpd-rs.service" ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          ExecStart = "${hwclock} -s --utc";
        };
      };
      r5c-hwclock-save = {
        description = "Save system clock to hardware RTC";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${hwclock} -w --utc";
        };
      };
      r5c-leds = {
        description = "Configure NanoPi R5C status LEDs";
        wantedBy = [ "multi-user.target" ];
        # wlan0 is created by the WiFi driver well after modules-load; wait for
        # its sysfs device so the green:wlan netdev trigger is not skipped.
        after = [
          "systemd-modules-load.service"
          "sys-subsystem-net-devices-wlan0.device"
        ];
        wants = [ "sys-subsystem-net-devices-wlan0.device" ];
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
    timers.r5c-hwclock-save = {
      description = "Periodically save system clock to hardware RTC";
      wantedBy = [ "timers.target" ];
      timerConfig = {
        OnBootSec = "5min";
        OnUnitActiveSec = "1h";
        Unit = "r5c-hwclock-save.service";
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
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
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
