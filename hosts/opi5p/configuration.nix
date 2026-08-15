{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  outboundProxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  proxyBypass = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  proxyEnvironment = {
    GOPROXY = "https://goproxy.cn,direct";
    HTTP_PROXY = outboundProxy;
    HTTPS_PROXY = outboundProxy;
    NO_PROXY = proxyBypass;
    http_proxy = outboundProxy;
    https_proxy = outboundProxy;
    no_proxy = proxyBypass;
  };
  # NCPS reaches mirror.sjtu.edu.cn through the router SOCKS5 proxy, and that
  # line intermittently times out. Keep other upstreams proxied, but let SJTU
  # requests go direct from the LAN.
  ncpsProxyBypass = "${proxyBypass},mirror.sjtu.edu.cn";
in
{
  imports = [
    ../../nixos/server.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/frigate-rockchip.nix
    ../../nixos/optional-apps/imou-bridge.nix
    ../../nixos/hardware/rockchip/accelerator-metrics.nix

    ./hardware-configuration.nix
    ./home-services.nix
    ./media-automation.nix
    ./qbittorrent-router.nix
  ];

  # This host is a native aarch64 builder. Registering qemu-arm through
  # binfmt would intercept reDroid's 32-bit ARM HAL binaries instead of
  # letting the kernel's native compat layer execute them.
  lantian.qemu-user-static-binfmt.enable = lib.mkForce false;

  # Fixed-output derivations execute on this native ARM builder. Route their
  # source downloads through the same stable egress as ml-builder instead of
  # relying on intermittent direct GitHub connectivity.
  environment.variables = proxyEnvironment;
  systemd.services.nix-daemon.environment = proxyEnvironment;
  systemd.services.ncps.environment = {
    HTTP_PROXY = config.lantian.ncps.proxy;
    HTTPS_PROXY = config.lantian.ncps.proxy;
    NO_PROXY = ncpsProxyBypass;
    http_proxy = config.lantian.ncps.proxy;
    https_proxy = config.lantian.ncps.proxy;
    no_proxy = ncpsProxyBypass;
  };
  # NCPS cache lives on the local NVMe-backed persistent filesystem, not on
  # the NFS-backed /mnt/storage. Kept together with the service's proxy
  # settings per module-placement-norms §2/§3.
  lantian.ncps = {
    dataPath = "/nix/persistent/var/cache/ncps";
    tempPath = "/nix/persistent/var/cache/ncps-tmp";
    proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    proxyUnit = null;
    storageUnit = "nix.mount";
  };

  # 两台乐橙摄像头 NVR（Frigate stable-rk 容器，RKNN NPU 检测）。
  # 摄像头本地密码在 secrets/frigate.yaml（key: bedroom-pw / livingroom-pw），
  # rtspUrl 里的 sops 占位符由 sops 模板渲染时替换为真实密码。
  lantian.frigate = {
    enable = true;
    cameras = {
      bedroom = {
        rtspUrl = "rtsp://admin:${config.sops.placeholder."frigate-bedroom-pw"}@192.168.0.104:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.104";
      };
      livingroom = {
        rtspUrl = "rtsp://admin:${config.sops.placeholder."frigate-livingroom-pw"}@192.168.0.115:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.115";
      };
    };
  };

  # 乐橙摄像头本地 RTSP 被锁死，走 Imou P2P 桥接（云中继 → 局域网 RTSP）。
  lantian.imouBridge.enable = true;
  # The private Attic endpoint occasionally needs slightly more than Nix's
  # five-second default to complete its public TLS handshake from this board.
  # Match ml-builder so a healthy private cache is not disabled prematurely.
  nix.settings.connect-timeout = lib.mkForce 15;

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

  # The common network policy intentionally masks the global wait-online
  # service. This host's NFS media mount must still wait for its physical LAN
  # carrier, so enable systemd's scoped per-interface instance only.
  systemd.targets.network-online.wants = [ "systemd-networkd-wait-online@lan0.service" ];

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

  # Break the boot ordering cycle between yggdrasil (Before=network.target),
  # the NFS mnt-storage mount (After=network.target) and nix-daemon.socket
  # (local-fs.target -> sockets.target). With the cycle, systemd drops
  # nix-daemon.socket at boot and ssh-ng deployment fails until the socket is
  # started manually. Yggdrasil still starts via multi-user.target.
  systemd.services.yggdrasil.unitConfig.Before = lib.mkForce [ ];

  # reDroid is intentionally disabled (2026-08, memory pressure policy; the
  # RKNN worker moved to ROCK 5C). While it stays off, keep the full zram
  # capacity available to the remaining services; revisit when reDroid returns.
  zramSwap.memoryPercent = lib.mkForce 100;

  # This is a production media/database/reDroid node first and an ARM builder
  # only as a compatibility fallback. One derivation at a time; let it use all
  # cores, but never run multiple memory-heavy derivations concurrently.
  nix.settings.max-jobs = lib.mkForce 1;
  assertions = [
    {
      assertion = LT.this.nixBuilder.maxJobs == 1 && config.nix.settings.max-jobs == 1;
      message = "opi5p must remain a single-job native ARM fallback builder; use ml-builder cross builds when possible";
    }
    {
      assertion = lib.hasInfix "mirror.sjtu.edu.cn" config.systemd.services.ncps.environment.NO_PROXY;
      message = "opi5p NCPS must bypass the proxy for mirror.sjtu.edu.cn; update ncpsProxyBypass and docs/network/ltnet-home-relay.md together";
    }
  ];

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

  # Android's bpfloader requires this to remain writable/enabled. The common
  # hardening policy sets it to the irreversible value 1, which cannot be
  # changed back until reboot and makes every official reDroid image shut down.
  # Keep ADB bound to the LAN address; do not expose this host publicly.
  boot.kernel.sysctl."kernel.unprivileged_bpf_disabled" = lib.mkForce 0;

  # CNflysky's RK3588 image is paired with the Armbian vendor kernel's Mali
  # CSF/Bifrost driver. Keep the image outside the immutable system closure;
  # Podman pulls it at runtime and stores Android state on persistent /nix.
  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    # Self-hosted acceleration via hubproxy on tencent (hub.tencent.zhyi.cc,
    # reached over the ZeroTier/LTNET tunnel). daocloud kept as fallback when
    # the tunnel is unreachable.
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.cc"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

  virtualisation.oci-containers.containers.redroid = {
    # Intentionally disabled (2026-08): reDroid stays off while memory is
    # shared with the production media/database stack. Re-enable deliberately
    # by removing this line.
    autoStart = lib.mkForce false;
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
      # CNflysky exposes ADB through the container Ethernet interface. Declare
      # both settings explicitly instead of relying on image defaults, so a
      # container/image refresh cannot silently disable network ADB. The host
      # port remains bound only to the home-LAN address above.
      "androidboot.redroid_adbd_bind_eth0=1"
      "ro.adb.secure=0"
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
    # Intentionally disabled together with the redroid container above.
    enable = lib.mkForce false;
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    environment = {
      HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
      HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
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

  # Byparr includes a browser runtime and its first GHCR pull is large.  Keep
  # the image pull on the same stable egress as the other OPI5P workloads.
  systemd.services.podman-byparr.environment = proxyEnvironment;

  # Ignis downloads the Obsidian app from its official source on first run;
  # keep that traffic on the router SOCKS5 proxy like the other workloads.
  systemd.services.podman-ignis.environment = proxyEnvironment;

  # Immich transcodes and extracts video thumbnails through ffmpeg. Use the
  # repo's Rockchip build (rkmpp/RGA) and let the service reach the VPU and
  # Mali render nodes; the default immich unit hides /dev and pins a plain
  # jellyfin-ffmpeg without rkmpp.
  systemd.services.immich-server = {
    path = [ pkgs.jellyfin-ffmpeg-rockchip ];
    serviceConfig = {
      PrivateDevices = lib.mkForce false;
      DevicePolicy = lib.mkForce "auto";
    };
  };
  users.users.immich.extraGroups = [ "video" "render" ];
  services.udev.extraRules = ''
    KERNEL=="cma", MODE="0660", GROUP="video"
  '';

  # OPI5P OOM-killed immich-server once while its 16 GiB was shared with the
  # RKNN worker, PostgreSQL, qBittorrent and ClamAV. ROCK 5C now owns the
  # distributed RKNN worker, so keep the NPU load off this node.
  lantian.immichRknnWorker.enable = lib.mkForce false;

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

  # The SFTP/data chain moved to OPI5P.  ml-home-vm is offline; this host is
  # both the backup server and a backup client, so point it at itself.
  lantian.backup.sftpEndpoint = "opi5p.zhyi.cc";
}
