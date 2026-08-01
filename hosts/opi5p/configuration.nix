{
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/jellyfin-rockchip.nix

    ./hardware-configuration.nix
    ./jellyfin.nix
  ];

  lantian.jellyfinRockchip.soc = "rk3588";

  # This host is a native aarch64 builder. Registering qemu-arm through
  # binfmt would intercept reDroid's 32-bit ARM HAL binaries instead of
  # letting the kernel's native compat layer execute them.
  lantian.qemu-user-static-binfmt.enable = lib.mkForce false;

  # Both onboard NICs use the same RTL8125 driver, so eth0/eth1 follow PCIe
  # probe order and can swap between boots. Match the permanent MAC addresses
  # for activation safety and give the ports stable names for later services.
  systemd.network.links."10-opi5p-lan0" = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fd";
    linkConfig.Name = "lan0";
  };
  systemd.network.links."10-opi5p-lan1" = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fc";
    linkConfig.Name = "lan1";
  };

  # Static network configuration for LAN access.
  systemd.network.networks.lan0 = {
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fd";
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  # Bring up the second RTL8125 as well.  A distinct LAN-only rescue address
  # avoids a competing default route while both physical ports are mapped.
  systemd.network.networks.lan1 = {
    address = [ "192.168.0.63/24" ];
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fc";
    networkConfig.IPv6AcceptRA = "yes";
  };
  networking.networkmanager.enable = lib.mkForce false;

  # Keep short-lived compiler objects off the relatively slow eMMC-backed
  # Btrfs filesystem. The limit is not reserved at boot; unused memory remains
  # available to reDroid and the kernel, with zram handling temporary pressure.
  fileSystems."/var/cache/nix" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=0755"
      "nodev"
      "nosuid"
      "size=8G"
    ];
  };
  systemd.services.nix-daemon.unitConfig.RequiresMountsFor = [ "/var/cache/nix" ];
  nix.settings.max-jobs = lib.mkForce 4;

  # `boot.supportedFilesystems` loads the kernel client, while nfs-utils
  # supplies mount.nfs.  Keep both host-local: this board reads the NAS
  # directly and must not route media through ml-home-vm.
  boot.supportedFilesystems = [ "nfs" ];
  environment.systemPackages = [ pkgs.nfs-utils ];

  # Media library is exported directly by the NAS; mount the same share the
  # other media hosts use without routing through ml-home-vm.
  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "hard"
      "vers=4.1"
      "nconnect=16"
    ];
  };

  # Never scan an empty local directory when the direct NAS mount is absent.
  systemd.services.jellyfin = {
    after = [ "mnt-storage.mount" ];
    requires = [ "mnt-storage.mount" ];
  };

  # Android's bpfloader requires this to remain writable/enabled. The common
  # hardening policy sets it to the irreversible value 1, which cannot be
  # changed back until reboot and makes every official reDroid image shut down.
  # Keep ADB bound to the LAN address; do not expose this host publicly.
  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

  # CNflysky's RK3588 image is paired with the Armbian vendor kernel's Mali
  # CSF/Bifrost driver. Keep the image outside the immutable system closure;
  # Podman pulls it at runtime and stores Android state on persistent /nix.
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

  virtualisation.oci-containers.containers.redroid = {
    image = "docker.io/cnflysky/redroid-rk3588:lineage-20";
    labels."io.containers.autoupdate" = "registry";
    privileged = true;
    ports = [ "${LT.this.interconnect.IPv4}:5555:5555" ];
    volumes = [
      "/nix/persistent/var/lib/redroid-rk3588-lineage20:/data"
    ];
    cmd = [
      # Define a portrait-native panel, then rotate it below. Android will
      # still render at 1280x720, but SystemUI uses its landscape side-navbar
      # layout instead of treating landscape as the natural rotation.
      "androidboot.redroid_width=720"
      "androidboot.redroid_height=1280"
      "androidboot.redroid_fps=60"
      # reDroid is connected through the container's Ethernet interface.
      # Some Android applications only start large downloads on Wi-Fi, so use
      # the image's supported Fake WiFi compatibility layer.
      "androidboot.redroid_fake_wifi=1"
      # Enable the Kitsune Magisk integration bundled with this image.
      "androidboot.redroid_magisk=1"
      # Match the upstream compose example instead of advertising a TV or
      # embedded-device product class to applications.
      "ro.build.characteristics=default"
    ];
  };

  systemd.tmpfiles.settings.redroid."/nix/persistent/var/lib/redroid-rk3588-lineage20"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  systemd.services.podman-redroid = {
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      HTTP_PROXY = "http://192.168.0.51:7892";
      HTTPS_PROXY = "http://192.168.0.51:7892";
      NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,docker.m.daocloud.io,.zhyi.cc,.zhyi.xin";
    };
    preStart = lib.mkBefore ''
      for attempt in $(${pkgs.coreutils}/bin/seq 1 60); do
        if ${pkgs.iproute2}/bin/ip -4 address show lan0 \
          | ${pkgs.gnugrep}/bin/grep -qF "inet ${LT.this.interconnect.IPv4}/24"; then
          break
        fi
        ${pkgs.coreutils}/bin/sleep 1
      done

      if ! ${pkgs.iproute2}/bin/ip -4 address show lan0 \
        | ${pkgs.gnugrep}/bin/grep -qF "inet ${LT.this.interconnect.IPv4}/24"; then
        echo "LAN address ${LT.this.interconnect.IPv4} is unavailable" >&2
        exit 1
      fi

      if ! test -c /dev/mali0; then
        echo "Armbian Mali CSF device /dev/mali0 is unavailable" >&2
        exit 1
      fi
    '';
  };

  systemd.services.redroid-landscape-navigation = {
    description = "Configure reDroid display, navigation, and application networking";
    wantedBy = [ "multi-user.target" ];
    after = [ "podman-redroid.service" ];
    requires = [ "podman-redroid.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      Restart = "on-failure";
      RestartSec = 5;
    };
    script = ''
      for attempt in $(${pkgs.coreutils}/bin/seq 1 90); do
        if ${pkgs.podman}/bin/podman exec redroid getprop sys.boot_completed \
          | ${pkgs.gnugrep}/bin/grep -qx 1; then
          ${pkgs.podman}/bin/podman exec redroid wm size reset
          ${pkgs.podman}/bin/podman exec redroid wm user-rotation lock 1
          # The image enables Android's restricted networking mode by default.
          # It blocks ordinary application UIDs (including TapTap) even while
          # the container, DNS, and Android's validated default network work.
          ${pkgs.podman}/bin/podman exec redroid settings put global restricted_networking_mode 0
          exit 0
        fi
        ${pkgs.coreutils}/bin/sleep 2
      done

      echo "reDroid did not finish booting within 180 seconds" >&2
      exit 1
    '';
  };
}
