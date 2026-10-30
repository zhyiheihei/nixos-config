{
  lib,
  pkgs,
  config,
  LT,
  ...
}:
let
  netns = config.lantian.netns.tnl-buyvm;
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  gatedServices = [
    "peerbanhelper"
    "podman-tachidesk"
    "jellyfin"
  ];

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
  jellyfinFontconfig = pkgs.writeText "jellyfin-fontconfig.conf" ''
    <?xml version="1.0"?>
    <!DOCTYPE fontconfig SYSTEM "urn:fontconfig:fonts.dtd">
    <fontconfig>
      <dir>${fallbackFontsDir}/share/fonts/opentype/noto-cjk</dir>
      <cachedir>/var/cache/fontconfig</cachedir>
      <match target="pattern">
        <edit name="family" mode="prepend" binding="strong">
          <string>Noto Sans CJK SC</string>
        </edit>
      </match>
    </fontconfig>
  '';
in
{

  powerManagement.cpuFreqGovernor = "performance";

  imports = [
    ../../nixos/optional-apps/jellyfin.nix
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

      jellyfin = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];

        confinement.packages = [ pkgs.intel-media-driver ];

        serviceConfig = {
          BindPaths = [ "/run/opengl-driver" ];
          BindReadOnlyPaths = [
            "/mnt/storage/media-radarr"
            "/mnt/storage/media-shortdrama"
            "/mnt/storage/media-sonarr"
            "${jellyfinFontconfig}:/etc/fonts/fonts.conf"
            "${fallbackFontsDir}"
          ];
        };
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
    (lib.genAttrs [
      "bitmagnet-dht"
      "bitmagnet-http"
      "bitmagnet-queue"
    ] (_: netns.bind { }))
  ];

  systemd.targets.media-automation = {
    description = "Media automation stack (migrated from dragon-q8b)";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices;
    after = [ "network.target" ];
  };

  lantian.nginxVhosts."jellyfin-backend.chromebox.zhyi.xin" = {
    listenHTTP = {
      enable = true;
      port = 8096;
      default = true;
    };
    listenHTTPS.enable = false;
    locations = {
      "/" = {
        proxyPass = "http://unix:/run/jellyfin/socket";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
      "= /web/" = {
        proxyPass = "http://unix:/run/jellyfin/socket:/web/index.html";
      };
    };
    accessibleBy = "private";
    noIndex.enable = true;
  };

  hardware.graphics = {
    enable = true;
    extraPackages = [ pkgs.intel-media-driver ];
  };

  services.jellyfin = {
    enable = true;
    forceEncodingConfig = true;
    transcoding.enableHardwareEncoding = true;
    transcoding.enableSubtitleExtraction = false;
    transcoding.hardwareDecodingCodecs = {
      h264 = true;
      hevc = true;
      hevc10bit = true;
    };
    hardwareAcceleration = {
      enable = true;
      type = "vaapi";
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
