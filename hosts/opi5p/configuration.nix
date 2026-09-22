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
      cfg
      // {
        listen = lib.mkForce (
          existing
          ++ [
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
    ../../nixos/optional-apps/food-dashboard.nix
    ../../nixos/optional-apps/frigate-rockchip.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/hydra
    ../../nixos/optional-apps/ignis.nix
    ../../nixos/optional-apps/immich-rockchip.nix
    ../../nixos/optional-apps/microsoft-rewards-script.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/openlist.nix
    ../../nixos/optional-apps/one-kvm.nix
    ../../nixos/optional-apps/redroid-rk3588.nix
    ../../nixos/optional-apps/ws-scrcpy.nix
    ../../nixos/optional-apps/resin.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/syncthing
    ../../nixos/optional-apps/taosync.nix
    ../../nixos/optional-apps/webdav.nix

    ../../nixos/optional-cron-jobs/radicale-calendar-sync.nix
    ../../nixos/optional-cron-jobs/rsgain-cloudmusic.nix
  ];

  ########################################
  # Native builder & NCPS cache egress
  ########################################

  # FOD 下载走统一出站代理。注意代理变量绝不喂给 nix-daemon（出站阻塞时
  # 连接不退，sshd/nix-daemon 连环孵化 OOM，两代硬件均复现），详见
  # docs/agent/outbound-proxy.md。
  environment.variables = LT.proxyEnvironment // {
    GOPROXY = "https://goproxy.cn,direct";
    NO_PROXY = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
    no_proxy = "${LT.proxyBypass},.m-team.cc,.m-team.io,api.m-team.io";
  };

  # daemon 只补 GOPROXY（goproxy.cn 直连可达，不经 router 代理，不落入上
  # 述 OOM 陷阱）：被分发到本机的 go-modules 类构建默认走 proxy.golang.org，
  # 其 IPv6 从本网络不可达，远程构建必失败（2026-09-06 ncps go-modules）。
  systemd.services.nix-daemon.environment.GOPROXY = "https://goproxy.cn,direct";

  # The private Attic endpoint occasionally needs slightly more than Nix's
  # five-second default to complete its public TLS handshake from this board.
  # Match ml-builder so a healthy private cache is not disabled prematurely.
  nix.settings.connect-timeout = lib.mkForce 15;

  # Hydra CI 自 2026-09-17 从 ml-laptop 迁入（构建拓扑见
  # docs/agent/hydra-build-chain.md）。本机承接 aarch64 原生构建，单槽
  # max-jobs=1（生产节点保护，见文档 2026-08-02 事故记录）；x86 与
  # aarch64-cross 全部外派 ml-builder。
  systemd.services.hydra-evaluator.environment = LT.proxyEnvironment;
  # qemu binfmt 关闭时 minimal-components 不设 extra-platforms，而
  # nix-distributed 生成 machines-with-localhost 时强制读取该属性；本机
  # 纯 aarch64 原生构建，显式置空。
  nix.settings.extra-platforms = lib.mkForce [ ];
  nix.buildMachines = lib.mkForce (
    let
      mk = n: maxJobs: features: {
        inherit (LT.hosts.${n}) system;
        hostName = "${n}.zhyi.xin";
        protocol = "ssh";
        speedFactor = LT.hosts.${n}.cpuThreads;
        sshKey = config.sops.secrets.hydra-builder-ssh-privkey.path;
        sshUser = "nix-builder";
        inherit maxJobs;
        supportedFeatures = features;
        mandatoryFeatures = [ ];
      };
    in
    [
      (mk "ml-builder" 2 [ "aarch64-cross" ])
      (mk "ml-builder" 1 [
        "big-parallel"
        "aarch64-cross"
      ])
    ]
  );
  services.hydra.buildMachinesFiles = lib.mkForce [ "/etc/nix/machines" ];

  # Hydra 产物每小时由 hydra-attic-repush 推到 attic（greencloud-jp），本地
  # GC roots 只是 push 期间的保险钉，无需按上游默认留 7 天（曾在本机
  # ml-laptop 上钉住 ~500G）。缩到 1 天：push 每小时重试仍有 ≥24 次成功机会。
  services.fast-nix-gc.deleteOlderThan = lib.mkForce "1d";

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

  # 静态 XOR 双 2.5G 口聚合,交换机侧为 SKS3200-5E1X Trunk1(UI Port4+Port5,
  # static)。该交换机的 LACP 协商从未完成(Aggregated 列始终为空),静态
  # 聚合才有 Aggregated 状态,与 ml-2700 成功先例完全同款。MAC 钉在 lan1 的
  # 烧录地址上,ARP/交换机表在重启与 PCIe 探测顺序变化后保持稳定。
  # 注意:networks.bond0 必须带 matchConfig.Name ——否则空 [Match] 会歧义
  # 匹配 lan0/lan1 并把 slave 从 bond 里抢走(boot 失联的直接根因)。
  systemd.network.netdevs.bond0 = {
    netdevConfig = {
      Kind = "bond";
      Name = "bond0";
      MACAddress = "c0:74:2b:ff:5c:fc";
    };
    bondConfig = {
      Mode = "balance-xor";
      TransmitHashPolicy = "layer3+4";
      MIIMonitorSec = "100ms";
    };
  };

  systemd.network.networks.lan0 = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fd";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.lan1 = {
    matchConfig.PermanentMACAddress = "c0:74:2b:ff:5c:fc";
    networkConfig.Bond = "bond0";
  };

  systemd.network.networks.bond0 = {
    matchConfig.Name = "bond0";
    address = [ "${LT.this.interconnect.IPv4}/24" ];
    dns = [ "192.168.0.1" ];
    domains = [ "zhyi.xin" ];
    networkConfig.IPv6AcceptRA = "yes";
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "192.168.0.1";
      }
    ];
  };
  networking.networkmanager.enable = lib.mkForce false;

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
  # noauto + automount：直接 mount 会卷入 ordering cycle（本机 bindfs 共享
  # 归 local-fs 却依赖 remote 挂载，与 network/local 链互相引用，systemd
  # 每次开机打断环后网络等待被删，挂载在地址未就绪时失败且永不重试）。
  # 写法对齐 exam lt-hp-omen 的 NAS 挂载；无 clientaddr（boot 早期地址未配
  # 好会被 mount.nfs 拒绝）、无 idle-timeout（下方 bindfs 通过 requires
  # 直接拉起本挂载，与 autofs 空闲卸载语义冲突）。
  fileSystems."/mnt/storage" = {
    device = "192.168.0.40:/nixos";
    fsType = "nfs";
    options = [
      "_netdev"
      "noatime"
      "noauto"
      "hard"
      "vers=4.1"
      "nconnect=16"
      "x-systemd.automount"
      "x-systemd.device-timeout=5s"
      "x-systemd.mount-timeout=5s"
    ];
  };

  # NAS 掉线窗口内的容器访问会反复触发 mount，默认 5 次/10s 限流会让
  # automount 连带永久 failed；解除限流后每次访问都是一次重试，NAS
  # 恢复后自动接上。fileSystems 生成器产物用 asDropin 下发配置。
  systemd.units."mnt-storage.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
  };

  # syncthing 模块生成的 bindfs 挂在 /mnt/storage（remote 挂载）之上，
  # 却默认归 local-fs.target，是 ordering cycle 的回边；_netdev 把它
  # 归入 remote-fs 链断环。共享模块不动，主机级覆盖。
  fileSystems."/run/syncthing-files".options = lib.mkForce [
    "bind"
    "_netdev"
  ];

  # 关 zram 改 NVMe swapfile：服务密度超物理内存时 zram 压缩把 kswapd
  # 吃满一核、陷入 swap 风暴（故事见 docs/human/hardware/orangepi-5-plus-redroid.md）。
  # swapfile 在独立子卷 /nix/swap：btrfs 快照不递归进子卷，避开
  # "Text file busy"（快照含活动 swapfile 会 EBUSY）。
  zramSwap.enable = lib.mkForce false;
  swapDevices = [
    {
      device = "/nix/swap/swapfile";
      size = 4096;
    }
  ];

  # 首启按需创建 swapfile（swapDevices 只激活已存在的文件）；
  # DefaultDependencies 必须关，否则与 basic.target 构成排序环。
  systemd.services.opi5p-swapfile-bootstrap = {
    description = "Create /nix/swap subvolume and swapfile before swap.target when missing";
    wantedBy = [ "swap.target" ];
    before = [
      "swap.target"
      "nix-swapfile.swap"
    ];
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
  # Frigate NVR（乐橙摄像头 ×2）
  ########################################

  # 摄像头本地密码在 secrets/frigate.yaml（key: bedroom-pw / livingroom-pw），
  # rtspUrl 里的 sops 占位符由 sops 模板渲染时替换为真实密码。
  # 注意：乐橙 App 里需关闭 RTSP 加密（TLS），否则 frigate 拉流失败。
  # One-KVM IP-KVM：板载 HDMI RX 采集 + Type-C OTG HID/MSD（详见 one-kvm.nix）。
  # 首启直接播种 app_config + 管理员，跳过 Web setup 向导（2026-09-11 用户决策）。
  # 实测硬件：HDMI RX 采集 = /dev/video0（stream_hdmirx，分辨率源自适应）。
  # 音频不启用：card0（rockchip-hdmiin）无 PCM 采集节点，板载 es8388 采的是
  # 板载 codec 而非被控机音频。UDC 仅 fc000000.usb 一个，留空自动选。
  # 管理密码复用全舰队 sops default-pw。视频 60fps 为用户指定默认值。
  lantian.one-kvm.enable = true;
  lantian.one-kvm.initialConfig = {
    enable = true;
    settings = {
      video = {
        device = "/dev/video0";
        fps = 60;
      };
      hid.backend = "otg";
      # 0.2.6 镜像 WebRTC 模式冷启动初始化死锁（详见 one-kvm.nix
      # unstickScript），默认用 mjpeg 模式（实测 1080p60 稳定）；
      # 需要时在 Web 界面切 H264/WebRTC。
      stream.mode = "mjpeg";
    };
  };

  # ws-scrcpy 网页版 scrcpy：浏览器镜像/控制 Android 设备（详见 ws-scrcpy.nix）。
  # 目标设备：opi5p 本机 redroid（rk3588）+ dragon-q8b redroid + 手机无线 adb
  # （启用后把手机 IP:5555 加进 adbHosts）。192.168.0.41 是尚未部署的待用
  # redroid 主机，先登记，设备起不来由 timer 自动重试。
  lantian.ws-scrcpy.enable = true;
  lantian.ws-scrcpy.adbHosts = [
    "192.168.0.62:5555"
    "192.168.0.66:5555"
    "192.168.0.41:5555"
  ];

  # OpenList + TaoSync 网盘备份链：Documents/Pictures 经 Syncthing 媒体盘
  # 只读挂载，定时同步到百度网盘（仅新增模式，删除不传染）。
  # 刷 token 走 OpenList 在线 API（外站）→ 出站代理；百度上传国内直连豁免。
  lantian.openlist.enable = true;
  lantian.taosync.enable = true;
  systemd.services.podman-openlist.environment = LT.proxyEnvironment // {
    NO_PROXY = "${LT.proxyBypass},.baidu.com,.baidubce.com";
    no_proxy = "${LT.proxyBypass},.baidu.com,.baidubce.com";
  };
  # TaoSync 只连 OpenList（podman 网关 10.88.0.1），不出外站，无需代理；
  # 且 requests 型 SOCKS 支持缺失会让它连本机引擎都报错。
  systemd.services.podman-taosync.environment = {
    HTTP_PROXY = "";
    HTTPS_PROXY = "";
    http_proxy = "";
    https_proxy = "";
  };

  # OpenList 公开服务（同 immich/jellyfin 走公网 8443 TLS 前沿，opi5p 是
  # 家宽公网唯一 TLS 前沿），Dex OAuth 保护；TaoSync 上游警告不暴露
  # 公网，保持 LTNET 私网。
  lantian.nginxVhosts."openlist.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Openlist}";
      proxyWebsockets = true;
      enableOAuth = true;
    };
    sslCertificate = "zerossl-${config.networking.hostName}.zhyi.xin";
    noIndex.enable = true;
  };
  lantian.localVhosts.taosync.locations."/" = {
    proxyPass = "http://127.0.0.1:${LT.portStr.TaoSync}";
    proxyWebsockets = true;
    enableOAuth = true;
  };

  # dav.zhyi.xin 公共名补齐：webdav 模块的 localVhost 只生成
  # dav.opi5p.zhyi.xin，公共名在 8443 无 vhost；rock5c 前置（内网 443）
  # 也指到本公共名，这里代理同一个 webdav.sock，凭据同全舰队 htpasswd。
  lantian.nginxVhosts."dav.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://unix:/run/webdav/webdav.sock";
      proxyNoTimeout = true;
      enableBasicAuth = true;
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # EPD 家庭食品存储看板：REST API + WebUI（内网私有，nginx food.opi5p.zhyi.xin）
  # + 每日 0 点墨水屏推送 timer；BLE 推送 NRF_EPD 墨水屏（服务私有，不开公网）。
  # 日程栏接标准 CalDAV（cal.zhyi.xin，Radicale，只读）；密码用统一 default-pw。
  # 测试阶段免鉴权（tokenFile = null）；转生产时用 sops 提供 token 后取消注释。
  lantian.food-dashboard = {
    enable = true;
    caldavUrl = "https://cal.zhyi.xin";
    caldavUser = "zhyi";
    caldavPasswordFile = config.sops.secrets.default-pw.path;
    caldavCalendar = "/zhyi/calendar/";
    # tokenFile = config.sops.secrets."epd-dashboard/api-token".path;
  };

  lantian.frigate = {
    enable = true;
    cameras = {
      bedroom = {
        rtspUrl = "rtsp://admin:${
          config.sops.placeholder."frigate-bedroom-pw"
        }@192.168.0.104:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.104";
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
      livingroom = {
        rtspUrl = "rtsp://admin:${
          config.sops.placeholder."frigate-livingroom-pw"
        }@192.168.0.115:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
        onvifHost = "192.168.0.115";
        zones.cat-area.coordinates = "0.13,0.18,0.87,0.18,0.87,0.83,0.13,0.83";
      };
    };
  };

  ########################################
  # Immich (Rockchip)
  ########################################

  systemd.services.immich-server = {
    path = [ pkgs.jellyfin-ffmpeg-rockchip ];
    serviceConfig = {
      PrivateDevices = lib.mkForce false;
      DevicePolicy = lib.mkForce "auto";
    };
  };
  users.users.immich.extraGroups = [
    "video"
    "render"
  ];
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

  services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";

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
  services.nginx.virtualHosts = lib.mkForce (lib.mapAttrs (_: with8443) config.lantian.nginxVhosts);

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

  # Jellyfin 定格 rock5c：本机只做公网 TLS 前沿，经 mesh IP 回源。
  lantian.nginxVhosts."jellyfin.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "https://${LT.hosts.rock5c.interconnect.IPv4}";
        proxyOverrideHost = "jellyfin.zhyi.xin";
        proxyWebsockets = true;
        proxyNoTimeout = true;
        extraConfig = ''
          proxy_ssl_server_name on;
          proxy_ssl_name jellyfin.zhyi.xin;
        '';
      };
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # QNAP NAS 管理界面（同网段直回源，QNAP 自带登录）。
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

  # Memos / Wallos：后端在 dragon-q8b，本机只做公网 TLS 前沿。
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

  # Tachidesk：后端在 dragon-q8b；basicAuth 两层 nginx 同一份 htpasswd
  # （客户端只需输入一次，满足 nginx-security 断言）。
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

  # Linkr：家庭内网设备（固定 IP；不用 mDNS 名——nginx 启动即解析
  # proxyPass 主机名，mDNS 抖动会炸 nginx）。
  lantian.nginxVhosts."linkr.opi5p.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://192.168.0.42";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
    };

    accessibleBy = "private";
    # 两级子域不在 zerossl-zhyi.xin 通配范围，须用本机通配证书。
    sslCertificate = "zerossl-opi5p.zhyi.xin";
    noIndex.enable = true;
  };
}
