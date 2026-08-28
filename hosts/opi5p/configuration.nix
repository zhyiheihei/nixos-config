{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  # 家庭宽带 WAN 443 被运营商封禁，公网 TLS 入口走 8443。nginx 的 vhost
  # 每 HTTPS 端口只能有一个，这里基于 lantian.nginxVhosts 重新生成
  # virtualHosts，给每个启用 TLS 的 vhost 追加 8443 监听（仅本主机生效）。
  publicHttpsPort = 8443;
  with8443 =
    v:
    let
      cfg = v._config;
      baseListen = cfg.listen; # lib.mkForce 的 override 包装，取 content
      existing = baseListen.content or baseListen;
      hasTLS = lib.any (l: lib.elem "ssl" (l.extraParameters or [ ])) existing;
    in
    if hasTLS then
      cfg // {
        listen = lib.mkForce (
          existing ++ [
            {
              addr = "0.0.0.0";
              port = publicHttpsPort;
              extraParameters = [ "ssl" ];
            }
          ]
        );
      }
    else
      cfg;
in
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
    ./media-center.nix
    ./shares.nix

    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/hardware/rockchip/accelerator-metrics.nix

    ../../nixos/optional-apps/asf.nix
    ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/frigate-rockchip.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/ignis.nix
    # Immich 单入口：rockchip 层内部已收编基础模块（immich.nix），并关闭
    # aarch64 上会构建失败的 nix 版 ML、改走 RKNN 推理（本机 rknn worker 又
    # 在下方 mkForce 关闭，推理现由 rock5c 承担）。
    ../../nixos/optional-apps/immich-rockchip.nix
    ../../nixos/optional-apps/ncps.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/resilio-sync.nix
    ../../nixos/optional-apps/redroid-rk3588.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/webdav.nix

    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix
  ];

  ########################################
  # Native builder & NCPS cache egress
  ########################################

  # Fixed-output derivations execute on this native ARM builder. Route their
  # source downloads through the same stable egress as ml-builder instead of
  # relying on intermittent direct GitHub connectivity.
  environment.variables = {
    GOPROXY = "https://goproxy.cn,direct";
    HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
    http_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    https_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  };
  systemd.services.nix-daemon.environment = config.environment.variables;
  # 让 NCPS 缓存写入本地 NVMe 持久盘（不在 NFS-backed /mnt/storage），并路由其
  # 上游下载走与构建一致的稳定出口。
  systemd.services.ncps.environment = lib.getAttrs [
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "NO_PROXY"
    "http_proxy"
    "https_proxy"
    "no_proxy"
  ] config.environment.variables;

  # The private Attic endpoint occasionally needs slightly more than Nix's
  # five-second default to complete its public TLS handshake from this board.
  # Match ml-builder so a healthy private cache is not disabled prematurely.
  nix.settings.connect-timeout = lib.mkForce 15;

  # This host is a native aarch64 builder; registering qemu binfmt emulators
  # is unnecessary and would only intercept native builds with slower paths.
  lantian.qemu-user-static-binfmt.enable = lib.mkForce false;

  # Keep short-lived compiler objects off the relatively slow eMMC-backed
  # Btrfs filesystem. Unused memory remains available to the remaining
  # services, with zram handling temporary pressure.
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

  ########################################
  # Networking & NAS storage mount
  ########################################

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

  # Break the boot ordering cycle between yggdrasil (Before=network.target),
  # the NFS mnt-storage mount (After=network.target) and nix-daemon.socket
  # (local-fs.target -> sockets.target). With the cycle, systemd drops
  # nix-daemon.socket at boot and ssh-ng deployment fails until the socket is
  # started manually. Yggdrasil still starts via multi-user.target.
  systemd.services.yggdrasil.unitConfig.Before = lib.mkForce [ ];

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

  # 关闭 zram：16GB 内存跑十几个重负载服务时，zram 的 zstd 压缩/解压
  # 让 kswapd0 吃满一个核（98.5% CPU），系统陷入 swap 风暴死亡螺旋
  # （load 181、全系统 D 状态、SSH 断连）。zram 在内存充裕时是好东西，
  # 但本机服务密度远超物理内存，zram 的 CPU 开销反而成了系统卡死的
  # 直接元凶。改用 NVMe swap 文件（GT50 直写 1.8GB/s），swap 读写走
  # 磁盘不吃 CPU，系统慢但不卡死；内存耗尽时 OOM killer 快速杀进程
  # 释放内存，比 zram 压缩死循环健康得多。
  zramSwap.enable = lib.mkForce false;
  swapDevices = [
    { device = "/nix/swapfile"; size = 4096; }
  ];

  ########################################
  # Frigate NVR（乐橙摄像头 ×2）
  ########################################

  # 摄像头本地密码在 secrets/frigate.yaml（key: bedroom-pw / livingroom-pw），
  # rtspUrl 里的 sops 占位符由 sops 模板渲染时替换为真实密码。
  # 注意：乐橙 App 里需关闭 RTSP 加密（TLS），否则 frigate 拉流失败。
  lantian.frigate = {
    enable = true;
    cameras = {
      bedroom = {
        rtspUrl = "rtsp://admin:${config.sops.placeholder."frigate-bedroom-pw"}@192.168.0.104:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.104";
        # 猫活动区：卧室画面中央主体区域（归一化 0~1 平铺坐标，相对 detect 帧），
        # 覆盖约中央 75%；供 HA 猫检测告警的 zone 过滤用，可在 UI 里微调顶点。
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
      livingroom = {
        rtspUrl = "rtsp://admin:${config.sops.placeholder."frigate-livingroom-pw"}@192.168.0.115:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.115";
        # 猫活动区（归一化平铺坐标，覆盖约中央 75%），供告警 zone 过滤。
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
    };
  };

  ########################################
  # Immich (Rockchip)
  ########################################

  # Transcodes and extracts video thumbnails through ffmpeg. Use the repo's
  # Rockchip build (rkmpp/RGA) and let the service reach the VPU and Mali
  # render nodes; the default immich unit hides /dev and pins a plain
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

  # OPI5P OOM-killed immich-server once while its 16 GiB was shared with other
  # heavy services. ROCK 5C owns the distributed RKNN worker, so keep the NPU
  # load off this node.
  lantian.immichRknnWorker.enable = lib.mkForce false;

  lantian.immich.storage = "/mnt/storage/immich";

  # Manual import drop folder for the Immich external library. It lives on the
  # NFS-backed /mnt/storage so both the immich service and zhyi (via SMB/SSH)
  # can reach it without crossing the immich-only /mnt/storage/immich root.
  systemd.tmpfiles.settings.immich-import."/mnt/storage/immich-import"."d" = {
    mode = "0775";
    user = "immich";
    group = "users";
  };

  ########################################
  # reDroid（停用中）
  ########################################

  # CNflysky's RK3588 image pairs with the Armbian vendor kernel's Mali
  # CSF/Bifrost driver (/dev/mali0); Podman pulls at runtime and Android state
  # persists under /nix/persistent. Intentionally disabled (2026-08, memory
  # pressure policy; the RKNN worker moved to ROCK 5C): flip
  # lantian.redroid.enable back to true to re-enable the whole stack
  # (container, LAN/mali0 preStart gates, landscape navigation).
  # While enabled on this native aarch64 builder, also keep
  # lantian.qemu-user-static-binfmt.enable off so reDroid's 32-bit ARM HAL
  # binaries are never intercepted by qemu emulation.
  lantian.redroid.enable = lib.mkForce false;

  ########################################
  # Home payloads storage locations
  ########################################

  services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";

  # Resilio Sync migrated from the QNAP NAS (2026-08). Identity and config
  # stay in the local /var/lib/resilio-sync; the synced folders are served
  # from the NFS share (bind-mounted at /sync and /downloads by the module).
  lantian.resilioSync = {
    dataDir = "/mnt/storage/resilio/data";
    downloadsDir = "/mnt/storage/resilio/downloads";
  };

  # Ignis vault is the knowledge-chain folder (Syncthing home copy on the
  # NFS share). Notes was merged into Documents (2026-08-20), so point the
  # vault at media/Documents; the module default still names media/Notes.
  lantian.ignis.enable = true;
  lantian.ignis.vaultDir = "/mnt/storage/media/Documents";

  # Ignis downloads the Obsidian app from its official source on first run;
  # keep that traffic on the router SOCKS5 proxy like the other workloads.
  systemd.services.podman-ignis.environment = {
    HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin";
  };

  # FlClash MKCOLs /FlClash/ before every WebDAV backup and webdav_client
  # treats MKCOL 405 as success, so pre-provision the writable target dir.
  systemd.tmpfiles.settings.flclash."/mnt/storage/FlClash"."d" = {
    mode = "0775";
    user = "zhyi";
    group = "users";
  };

  # The hourly timer can fire before sops-install-secrets writes the calendar
  # sync script on a fresh boot; make the run wait for the secret explicitly.
  systemd.services.radicale-calendar-sync = {
    after = [ "sops-install-secrets.service" ];
    requires = [ "sops-install-secrets.service" ];
  };

  ########################################
  # Public TLS front (8443) for the home edge
  ########################################

  # 让 8443 由 nginx 原生监听（router 直通到本机 8443，不再转换到 443）。
  services.nginx.virtualHosts = lib.mkForce (
    lib.mapAttrs (_: with8443) config.lantian.nginxVhosts
  );

  networking.hosts."${LT.this.interconnect.IPv4}" = [
    "vaults3.zhyi.xin"
    "jellyfin.zhyi.xin"
    "qnap.zhyi.xin"
    "tachidesk.zhyi.xin"
  ];

  # VaultS3 runs natively on the router (192.168.0.1:9000); opi5p keeps the
  # public TLS front for the 8443 compatibility endpoint (router DNATs
  # 8443 -> opi5p:8443).
  lantian.nginxVhosts."vaults3.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:9000";
        proxyOverrideHost = "$http_host";
        proxyNoTimeout = true;
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # 家宽 WAN 443 被运营商封禁，router 把公网 8443 DNAT 直通 opi5p:8443（端口不变）。
  # 这三个域名解析到 home-ddns（家宽 IP），公网只能经 8443 进入，
  # 所以 TLS 前沿必须落在 opi5p（而非原本只监听家内 443 的 rock5c）。
  # 后端沿用各服务现有 HTTP 中转 vhost，不回源公网 DNS，避免环路。

  # Jellyfin 本体迁到 macmini（192.168.0.54，VideoToolbox 硬解），直接监听
  # HTTP 8096。mac 不装 nginx（nix-darwin 无 services.nginx/nginxVhosts），
  # opi5p 保持公网 TLS 前沿，回源指 mac。认证为 Jellyfin 自带登录，无 basicAuth。
  lantian.nginxVhosts."jellyfin.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://${LT.hosts.macmini.interconnect.IPv4}:8096";
        proxyOverrideHost = "$http_host";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # QNAP NAS 管理界面，与 opi5p 同网段，直接回源 NAS 自身。
  # 认证与 rock5c 的 qnap.zhyi.xin 一致（无 basicAuth，QNAP 自带登录）。
  lantian.nginxVhosts."qnap.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://192.168.0.40:8080";
        proxyOverrideHost = "$http_host";
        proxyWebsockets = true;
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # Memos / Wallos / FileCodeBox / Sun Panel 迁到 dragon-q8b（Qualcomm
  # SC8280XP）。opi5p 保持公网 8443 TLS 前沿，回源 dragon-q8b 内网 443。
  lantian.nginxVhosts."memos.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "memos.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name memos.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."wallos.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "wallos.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name wallos.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."filebox.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "filebox.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name filebox.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."index.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "index.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name index.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."index-helper.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "index-helper.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name index-helper.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # Tachidesk 迁至 dragon-q8b，opi5p 保持公网 8443 TLS 前沿，回源 dragon-q8b。
  # basicAuth 在两层 nginx 上都启用（同一份 htpasswd，客户端只需输入一次），
  # 满足 nginx-security 策略断言且不改变访问控制语义。
  lantian.nginxVhosts."tachidesk.zhyi.xin" = {
    locations = {
      "/" = {
        enableBasicAuth = true;
        proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
        proxyOverrideHost = "tachidesk.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name tachidesk.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };
}
