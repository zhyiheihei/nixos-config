{
  config,
  lib,
  modulesPath,
  pkgs,
  self,
  ...
}:
let
  # Keep compiler processes native on ml-builder while they emit aarch64
  # binaries. H28K must not build its own kernel or U-Boot under qemu-user.
  crossPkgs =
    self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform;

  # Linux 6.18 has the RK3528 base support, but it predates the PCIe and USB
  # nodes, the RK3528 USB2 PHY support, and the H28K board DTS. Keep the exact
  # upstream commits in dependency order; the board DTS cannot even compile
  # against the unpatched 6.18 rk3528.dtsi.
  h28kKernel = crossPkgs.linuxManualConfig {
    inherit (crossPkgs.linux_6_18) src version modDirVersion;
    configfile = ../nanopi-r5c/kernel-config;
    kernelPatches = [
      {
        name = "rk3528-pcie-dts";
        patch = ./rk3528-backport-01-pcie-dts.patch;
      }
      {
        name = "rk3528-inno-usb2-usbgrf";
        patch = ./rk3528-backport-02-inno-usb2-usbgrf.patch;
      }
      {
        name = "rk3528-inno-usb2-clkout";
        patch = ./rk3528-backport-03-inno-usb2-clkout.patch;
      }
      {
        name = "rk3528-inno-usb2-support";
        patch = ./rk3528-backport-04-inno-usb2-support.patch;
      }
      {
        name = "rk3528-usb-dts";
        patch = ./rk3528-backport-05-usb-dts.patch;
      }
      {
        name = "hinlink-h28k-dts";
        patch = ./0001-arm64-dts-rockchip-add-hinlink-h28k.patch;
      }
    ];
  };

  # The PCIe RTL8111H uses this optional r8169 firmware. Keep only that file
  # instead of retaining the complete linux-firmware closure on a router.
  rtl8168hFirmware = crossPkgs.buildPackages.runCommand "h28k-rtl8168h-firmware" { } ''
    source=${pkgs.linux-firmware}/lib/firmware
    mkdir -p "$out/lib/firmware/rtl_nic"
    cp -L "$source/rtl_nic/rtl8168h-2.fw" "$out/lib/firmware/rtl_nic/"
  '';

  # Mainline U-Boot has generic RK3528 SD/eMMC support. The current rkbin
  # package contains the matching RK3528 DDR TPL and BL31 even though Nixpkgs
  # does not yet expose them as passthru attributes.
  ubootH28K = crossPkgs.buildUBoot {
    defconfig = "generic-rk3528_defconfig";
    extraMeta.platforms = [ "aarch64-linux" ];
    requiredSystemFeatures = [ "aarch64-cross" ];
    env = {
      BL31 = "${crossPkgs.rkbin}/bin/rk35/rk3528_bl31_v1.21.elf";
      ROCKCHIP_TPL = "${crossPkgs.rkbin}/bin/rk35/rk3528_ddr_1056MHz_v1.13.bin";
    };
    filesToInstall = [ "u-boot-rockchip.bin" ];
  };

  configureLeds = pkgs.writeShellScript "h28k-configure-leds" ''
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

    # The upstream DTS maps amber to LAN, blue to WAN and green to status.
    # Link LEDs stay lit with carrier and blink for traffic; the status LED
    # uses heartbeat so a frozen kernel can be distinguished from a live one.
    set_netdev_trigger "amber:lan" "eth0"
    set_netdev_trigger "blue:wan" "eth1"
    set_trigger "green:status" "heartbeat"
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
    initrd.kernelModules = lib.mkForce [ ];
    kernelModules = lib.mkForce [
      "r8169"
      "ledtrig_netdev"
    ];
    extraModulePackages = lib.mkForce [ ];
    kernelParams = [
      # UART0 is the console selected by the accepted H28K DTS.
      "earlycon=uart8250,mmio32,0xff9f0000"
      "console=ttyS0,1500000n8"
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

  lantian.kernel = lib.mkForce h28kKernel;

  honkai-railway-grub-theme.enable = lib.mkForce false;
  systemd.services.install-random-star-rail-grub-theme.enable = false;

  hardware = {
    enableRedistributableFirmware = lib.mkForce false;
    firmware = [ rtl8168hFirmware ];
  };

  hardware.deviceTree = {
    name = "rockchip/rk3528-hinlink-h28k.dtb";
    filter = "rk3528-hinlink-h28k.dtb";
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

  systemd.services = {
    h28k-grow-nix = {
      description = "Expand H28K persistent Nix filesystem";
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

    h28k-leds = {
      description = "Configure H28K router status LEDs";
      wantedBy = [ "multi-user.target" ];
      after = [
        "systemd-modules-load.service"
        "network.target"
      ];
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

  sdImage = {
    # The combined Rockchip image contains TPL/SPL, U-Boot and BL31 and is
    # written at sector 64 (32 KiB). Keep partition 1 at 16 MiB so the loader
    # can never be overwritten by the partition table or filesystems.
    firmwarePartitionOffset = 16;
    firmwarePartitionName = "FIRMWARE";
    firmwareSize = 256;
    rootFilesystemCreator = ../make-nix-btrfs-fs.nix;
    rootPartitionUUID = "12c85f66-ac79-4c7d-b0d0-56646ea25c95";
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
      dd if=${ubootH28K}/u-boot-rockchip.bin of="$img" seek=64 conv=notrunc status=none
    '';
  };
}
