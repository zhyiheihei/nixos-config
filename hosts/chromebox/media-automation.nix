{
  lib,
  pkgs,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  gatedServices = [
    "peerbanhelper"
    "podman-tachidesk"
    "jellyfin"
  ];
  # 网页字幕渲染的 CJK 回退字体（同 rock5c media-apps.nix，Jellyfin
  # 只收 ttf/otf/woff 且总量限 20MB，用单区 SC OTF）。烧录路径走系统
  # fontconfig。
  jellyfinFallbackFont = pkgs.fetchurl {
    urls = [
      "https://cdn.jsdelivr.net/gh/notofonts/noto-cjk@Sans2.004/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"
      "https://raw.githubusercontent.com/notofonts/noto-cjk/Sans2.004/Sans/OTF/SimplifiedChinese/NotoSansCJKsc-Regular.otf"
    ];
    hash = "sha256-LHYlT2/Def3fzgp+hPtThbsTXT45kpT27rZoDQNlt0s=";
  };
  fallbackFontsDir = pkgs.runCommand "noto-sans-cjk-sc-fallback" { } ''
    install -Dm644 ${jellyfinFallbackFont} $out/share/fonts/opentype/noto-cjk/NotoSansCJKsc-Regular.otf
  '';
in
{
  # 游戏服务器常驻高负载，powersave 降频会造成顿卡（2026-10-14 排查）。
  powerManagement.cpuFreqGovernor = "performance";

  imports = [
    ../../nixos/optional-apps/resilio-sync.nix
    ../../nixos/optional-apps/clamav.nix
    ../../nixos/optional-apps/peerbanhelper.nix
    ../../nixos/optional-apps/tachidesk.nix
    ../../nixos/optional-apps/bitmagnet.nix
  ];

  lantian.resilioSync = {
    dataDir = "/mnt/storage/resilio/data";
    downloadsDir = "/mnt/storage/resilio/downloads";
  };

  boot.supportedFilesystems = [ "nfs" ];
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
  fileSystems."/sync".options = lib.mkForce [
    "bind"
    "_netdev"
  ];
  fileSystems."/downloads".options = lib.mkForce [
    "bind"
    "_netdev"
  ];
  systemd.units."mnt-storage.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      StartLimitIntervalSec=0
    '';
  };

  environment.etc."containers/registries.conf.d/99-mirrors.conf".text = ''
    [[registry]]
    location = "docker.io"

    [[registry.mirror]]
    location = "hub.tencent.zhyi.xin"

    [[registry.mirror]]
    location = "docker.m.daocloud.io"
  '';

  systemd.services = lib.mkMerge [
    {
      # .NET 应用不认 socks5，走 router v2ray 的 HTTP CONNECT 入站拉
      # TMDB/图片等外网元数据；media 库挂在 QNAP NFS 上，NAS 就绪前不扫盘。
      jellyfin = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
        # 同 jellyfin-rockchip 模块：RestartSec ≥ 3s 过 ensure-service-restart 策略。
        serviceConfig.RestartSec = "5s";
        environment = LT.proxyEnvironment // {
          HTTP_PROXY = "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.V2Ray.HttpClient}";
          HTTPS_PROXY = "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.V2Ray.HttpClient}";
          http_proxy = "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.V2Ray.HttpClient}";
          https_proxy = "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.V2Ray.HttpClient}";
        };
      };
      resilio.serviceConfig = {
        LogRateLimitIntervalSec = 30;
        LogRateLimitBurst = 500;
        MemoryMax = "3G";
      };
    }
    (lib.genAttrs gatedServices (_: {
      partOf = [ "media-automation.target" ];
      unitConfig.ConditionPathExists = activationMarker;
    }))
    (lib.genAttrs
      [
        "bitmagnet-dht"
        "bitmagnet-http"
        "bitmagnet-queue"
      ]
      (_: {
        partOf = [ "media-automation.target" ];
        unitConfig.ConditionPathExists = activationMarker;
        environment = LT.proxyEnvironment;
      })
    )
  ];

  systemd.targets.media-automation = {
    description = "Media automation stack (migrated from dragon-q8b)";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices;
    after = [ "network.target" ];
  };

  # Jellyfin（自 rock5c 迁入家庭边缘，2026-10-16）：UHD 620 走 QSV 硬解/
  # 硬编（H.264/HEVC 10bit），多会话轻转码不再受 rock5c 8G 内存天花板
  # 约束。forceEncodingConfig 用本机 QSV 覆盖随状态 rsync 带来的 rkmpp
  # 编码配置，NixOS 配置成为 encoding.xml 唯一真源。
  services.jellyfin = {
    enable = true;
    forceEncodingConfig = true;
    transcoding.enableHardwareEncoding = true;
    hardwareAcceleration = {
      enable = true;
      type = "qsv";
      device = "/dev/dri/renderD128";
    };
  };

  users.users.jellyfin.extraGroups = [
    "render"
    "video"
  ];

  fonts.packages = [ fallbackFontsDir ];

  systemd.tmpfiles.settings.media-automation = {
    "/var/lib/jellyfin/fonts"."L+" = {
      argument = "${fallbackFontsDir}/share/fonts/opentype/noto-cjk";
      user = "jellyfin";
      group = "jellyfin";
    };
    "/nix/persistent/var/lib/media-automation".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    "/nix/persistent/var/lib/postgresql" = {
      d = {
        mode = "0700";
        user = "postgres";
        group = "postgres";
      };
      h.argument = "+C";
    };
  };
}
