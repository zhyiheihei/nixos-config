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
    ../../nixos/optional-apps/frigate-rockchip.nix
    ../../nixos/optional-apps/home-assistant.nix
    ../../nixos/optional-apps/ignis.nix
    ../../nixos/optional-apps/immich-rockchip.nix
    ../../nixos/optional-apps/microsoft-rewards-script.nix
    ../../nixos/optional-apps/ncps-client.nix
    ../../nixos/optional-apps/one-kvm.nix
    ../../nixos/optional-apps/redroid-rk3588.nix
    ../../nixos/optional-apps/resin.nix
    ../../nixos/optional-apps/sftp-server.nix
    ../../nixos/optional-apps/syncthing
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
  # One-KVM IP-KVM：板载 HDMI RX 采集 + Type-C OTG HID/MSD（详见 one-kvm.nix）
  lantian.one-kvm.enable = true;

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

  # services.calibre-cops.libraryPath = "/mnt/storage/media/Calibre Library";

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
