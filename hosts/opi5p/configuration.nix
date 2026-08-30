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
    # ./shares.nix

    ../../nixos/client-components/multicast-dns.nix

    ../../nixos/hardware/rockchip/accelerator-metrics.nix

    # 2026-08-29 重装过渡期：重服务临时摘除（SD 卡性能不足 + sops 未就绪时
    # 这些服务只会循环崩溃拖垮机器），NVMe 落定后分批恢复。
    # 2026-08-30：NVMe 已落定，按 §3.3 硬件依赖清单分批恢复
    #（frigate → immich）；asf/cops/ignis/syncthing/webdav 等 NAS/状态类
    # 服务随迁移决策另定，不在本机恢复。
    # ../../nixos/optional-apps/asf.nix
    # ../../nixos/optional-apps/calibre-cops.nix
    ../../nixos/optional-apps/frigate-rockchip.nix
    # ../../nixos/optional-apps/home-assistant.nix
    # ../../nixos/optional-apps/ignis.nix
    # Immich 单入口：rockchip 层内部已收编基础模块（immich.nix），并关闭
    # aarch64 上会构建失败的 nix 版 ML、改走 RKNN 推理（本机 rknn worker 又
    # 在下方 mkForce 关闭，推理现由 rock5c 承担）。
    ../../nixos/optional-apps/immich-rockchip.nix
    # ncps 服务端与 resilio-sync 引擎已迁至 dragon-q8b（2026-08-28），
    # 本机保留 ncps-client 作为缓存消费者。
    ../../nixos/optional-apps/ncps-client.nix
    # ../../nixos/optional-apps/redroid-rk3588.nix
    ../../nixos/optional-apps/sftp-server.nix
    # ../../nixos/optional-apps/syncthing
    # ../../nixos/optional-apps/webdav.nix

    # ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    # ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix
  ];

  ########################################
  # Native builder & NCPS cache egress
  ########################################

  # Fixed-output derivations execute on this native ARM builder. Route their
  # source downloads through the same stable egress as ml-builder instead of
  # relying on intermittent direct GitHub connectivity.
  #
  # 2026-08-29: 这些代理变量绝不喂给 nix-daemon（曾用
  # `systemd.services.nix-daemon.environment = config.environment.variables`
  # 全量灌入）。daemon 的出站 HTTP 经 router V2Ray 阻塞时连接不退，客户端
  # 超时重连 → sshd/nix-daemon 连环孵化 → OOM 死循环（2TB NVMe 时代与本次
  # SD 重装均复现；dragon/ml-builder 的 daemon 无代理故永不触发）。
  # 代理只作用于交互 shell 与显式声明代理的服务。
  environment.variables = {
    GOPROXY = "https://goproxy.cn,direct";
    HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
    http_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    https_proxy = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
    no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  };

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
  # swapfile 必须放在独立子卷 /nix/swap 里：backup-nix-persistent 会对 /nix
  # 做只读快照，而 btrfs 禁止快照含活动 swapfile 的子卷（EBUSY
  # "Text file busy"，2026-08-30 实证）。本机 btrfs 没有任何子卷布局
  #（persistent 是普通目录，snapshot -r /nix 会带上它），swapfile 挪路径
  # 无解，必须单独开子卷——snapshot 不递归进入子卷，EBUSY 与备份冗余
  # 两个问题同时消失，swapfile 也不需要进 resticIgnored。
  swapDevices = [
    { device = "/nix/swap/swapfile"; size = 4096; }
  ];

  # swapDevices 只激活已存在的文件；dd 镜像首启时 swapfile 不存在，
  # swap 单元直接 failed（2026-08-29 实证：全机无 swap 兜底放大了 daemon
  # 堆积的破坏）。镜像不带 4G 文件（浪费体积），首启按需创建。
  # DefaultDependencies 必须关：默认隐式 After=basic.target 会构成
  # swap.target → 本单元 → basic.target → sysinit.target → swap.target
  # 排序环，systemd 直接删掉 swap.target（2026-08-30 NVMe 首启实证：swap 整轮没起）。
  systemd.services.opi5p-swapfile-bootstrap = {
    description = "Create /nix/swap subvolume and swapfile before swap.target when missing";
    wantedBy = [ "swap.target" ];
    before = [ "swap.target" "nix-swapfile.swap" ];
    requires = [ "nix.mount" ];
    after = [ "nix.mount" ];
    unitConfig = {
      DefaultDependencies = lib.mkForce false;
      ConditionPathExists = "!/nix/swap/swapfile";
    };
    serviceConfig = {
      Type = "oneshot";
      ExecStart = [
        "${pkgs.util-linux}/bin/test -d /nix/swap || ${pkgs.btrfs-progs}/bin/btrfs subvolume create /nix/swap"
        "${pkgs.coreutils}/bin/touch /nix/swap/swapfile"
        "${pkgs.e2fsprogs}/bin/chattr +C /nix/swap/swapfile"
        "${pkgs.coreutils}/bin/dd if=/dev/zero of=/nix/swap/swapfile bs=1M count=4096 status=none"
        "${pkgs.coreutils}/bin/chmod 600 /nix/swap/swapfile"
        "${pkgs.util-linux}/bin/mkswap /nix/swap/swapfile"
      ];
    };
  };

  ########################################
  # Frigate NVR（乐橙摄像头 ×2）—— 重装过渡期摘除，NVMe 落定后恢复
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
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
      livingroom = {
        rtspUrl = "rtsp://admin:${config.sops.placeholder."frigate-livingroom-pw"}@192.168.0.115:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.115";
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
    };
  };

  ########################################
  # Immich (Rockchip) —— 重装过渡期摘除，2026-08-30 随批次 2 恢复
  ########################################

  # 注意：旧 NVMe 的 postgres（immich 库）已从 NAS rustic 快照恢复
  #（2026-08-30，restic 仓 ba4e6365 = 08-27 状态）。
  # immich uid/gid 必须钉死为 984:982：NAS /mnt/storage/immich 全树与
  # 恢复的本地状态文件都属 984:982（0700），新系统自动分配的 uid 对不上
  # 会 EACCES（2026-08-30 实证 encoded-video/.immich 读不了）。
  users.users.immich.uid = lib.mkForce 984;
  users.groups.immich.gid = lib.mkForce 982;
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
  lantian.immichRknnWorker.enable = lib.mkForce false;
  lantian.immich.storage = "/mnt/storage/immich";
  systemd.tmpfiles.settings.immich-import."/mnt/storage/immich-import"."d" = {
    mode = "0775";
    user = "immich";
    group = "users";
  };

  ########################################
  # reDroid（停用中）—— 模块导入已注释，配置一并摘除
  ########################################

  # lantian.redroid.enable = lib.mkForce false;

  ########################################
  # Home payloads storage locations
  ########################################

  # services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";

  # Resilio Sync 引擎已迁至 dragon-q8b（2026-08-28）；同步的数据本体仍
  # 在 NAS（/mnt/storage/resilio/*）。本机 /nix/persistent/var/lib/resilio-sync
  # 的 identity/索引随迁移拷走，确认 dragon 稳定后可删除回收空间。

  # lantian.ignis.enable = true;
  # lantian.ignis.vaultDir = "/mnt/storage/media/Documents";

  # systemd.services.podman-ignis.environment = {
  #   HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  #   HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  #   NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin";
  # };

  # FlClash MKCOLs /FlClash/ before every WebDAV backup and webdav_client
  # treats MKCOL 405 as success, so pre-provision the writable target dir.
  # systemd.tmpfiles.settings.flclash."/mnt/storage/FlClash"."d" = {
  #   mode = "0775";
  #   user = "zhyi";
  #   group = "users";
  # };

  # systemd.services.radicale-calendar-sync = {
  #   after = [ "sops-install-secrets.service" ];
  #   requires = [ "sops-install-secrets.service" ];
  # };

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
