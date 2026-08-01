{
  config,
  lib,
  LT,
  pkgs,
  utils,
  ...
}:
let
  cfg = config.lantian.jellyfinRockchip;
  netns = config.lantian.netns.rk-jellyfin;
  proxy = "http://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  hasAv1Decoder = builtins.elem cfg.soc [
    "rk3528"
    "rk3588"
  ];
  loggingConf = {
    Serilog = {
      Using = [ "Serilog.Sinks.Console" ];
      MinimumLevel = "Warning";
      WriteTo = [ { Name = "Console"; } ];
      Enrich = [
        "FromLogContext"
        "WithMachineName"
        "WithThreadId"
      ];
      Properties.Application = "Jellyfin";
    };
  };
in
{
  options.lantian.jellyfinRockchip.soc = lib.mkOption {
    type = lib.types.enum [
      "rk3528"
      "rk3566"
      "rk3568"
      "rk3588"
    ];
    description = "Rockchip RK35 SoC whose MPP codec capabilities Jellyfin should use.";
  };

  config = {
    assertions = [
      {
        assertion = pkgs.stdenv.hostPlatform.isAarch64;
        message = "jellyfin-rockchip.nix requires an aarch64 Rockchip host";
      }
    ];

    services.jellyfin = {
      enable = true;
      package = pkgs.jellyfin.override {
        jellyfin-ffmpeg = pkgs.jellyfin-ffmpeg-rockchip;
      };

      hardwareAcceleration = {
        enable = true;
        type = "rkmpp";
        device = "/dev/mpp_service";
      };
      forceEncodingConfig = true;
      transcoding = {
        enableHardwareEncoding = true;
        enableToneMapping = true;
        hardwareDecodingCodecs = {
          h264 = true;
          hevc = true;
          hevc10bit = true;
          mpeg2 = true;
          vp8 = true;
          vp9 = true;
          av1 = hasAv1Decoder;
        };
        # The supported RK35 variants encode H.264 and HEVC, not AV1.
        hardwareEncodingCodecs = {
          hevc = true;
          av1 = false;
        };
      };
    };

    users.users.jellyfin.extraGroups = [
      "video"
      "render"
    ];

    lantian.netns.rk-jellyfin.ipSuffix = "49";

    lantian.nginxVhosts = {
      "rk-jellyfin.zhyi.xin" = {
        locations = {
          "/".proxyPass = "http://unix:/run/jellyfin/socket";
          "= /web/".proxyPass = "http://unix:/run/jellyfin/socket:/web/index.html";
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "rk-jellyfin.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations = {
          "/".proxyPass = "http://unix:/run/jellyfin/socket";
          "= /web/".proxyPass = "http://unix:/run/jellyfin/socket:/web/index.html";
        };
        noIndex.enable = true;
        accessibleBy = "localhost";
      };
    };

    systemd.services.jellyfin = netns.bind {
      environment = {
        HTTP_PROXY = proxy;
        HTTPS_PROXY = proxy;
        NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
        http_proxy = proxy;
        https_proxy = proxy;
        no_proxy = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";
        JELLYFIN_kestrel__socket = "true";
        JELLYFIN_kestrel__socketPath = "/run/jellyfin/socket";
        JELLYFIN_kestrel__socketPermissions = "0777";
        JELLYFIN_PublishedServerUrl = "https://rk-jellyfin.zhyi.xin";
      };
      serviceConfig = {
        RuntimeDirectory = "jellyfin";
        ExecStartPre = pkgs.writeShellScript "jellyfin-rockchip-pre" ''
          ${utils.genJqSecretsReplacementSnippet loggingConf "/var/lib/jellyfin/config/logging.json"}
        '';
        DeviceAllow = lib.mkAfter [
          "/dev/mpp_service rw"
          "/dev/rga rw"
          "/dev/dri/renderD128 rw"
          "/dev/dri/renderD129 rw"
          "/dev/dma_heap/system rw"
          "/dev/dma_heap/system-dma32 rw"
          "/dev/dma_heap/system-uncached rw"
          "/dev/dma_heap/system-uncached-dma32 rw"
        ];
      };
    };
  };
}
