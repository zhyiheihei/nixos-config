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
  hasHdrToneMapping = cfg.soc == "rk3588";
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
        # RK3588 can keep the RKMPP -> OpenCL -> RKMPP path zero-copy. The
        # other supported RK35 SoCs cannot perform hardware HDR tone mapping.
        enableToneMapping = hasHdrToneMapping;
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

    # Jellyfin's official Armbian 6.1 recipe pins this exact g24p0 runtime.
    # Keep only its OpenCL shim in the graphics driver environment so the
    # proprietary EGL/GLES/GBM libraries do not replace NixOS Mesa.
    hardware.graphics = lib.mkIf hasHdrToneMapping {
      enable = true;
      extraPackages = [ pkgs.libmali-rockchip-g610 ];
    };
    hardware.firmware = lib.mkIf hasHdrToneMapping [ pkgs.libmali-rockchip-g610 ];

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
      environment =
        {
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
        }
        // lib.optionalAttrs hasHdrToneMapping {
          # ocl-icd does not discover hardware.graphics' vendor directory by
          # itself. Point Jellyfin/FFmpeg at the pinned Armbian Mali runtime so
          # the zero-copy RKMPP -> OpenCL -> RKMPP HDR path is available.
          OCL_ICD_VENDORS = "${pkgs.libmali-rockchip-g610}/etc/OpenCL/vendors";
          LD_LIBRARY_PATH = "${pkgs.libmali-rockchip-g610}/lib";
        };
      serviceConfig = {
        RuntimeDirectory = "jellyfin";
        # Rockchip MPP identifies the SoC through
        # /proc/device-tree/compatible.  NixOS' generic Jellyfin hardening
        # uses ProcSubset=pid, which hides that non-process procfs subtree.
        ProcSubset = lib.mkForce "all";
        # Preserve the numeric video/render supplementary groups inside the
        # user namespace. The generic "self" mapping turns those device
        # groups into nobody; "identity" retains capability isolation while
        # keeping the low system UID/GID range stable.
        PrivateUsers = lib.mkForce "identity";
        ExecStartPre = pkgs.writeShellScript "jellyfin-rockchip-pre" ''
          ${utils.genJqSecretsReplacementSnippet loggingConf "/var/lib/jellyfin/config/logging.json"}
        '';
        DeviceAllow = lib.mkAfter [
          "/dev/mali0 rw"
          "/dev/mpp_service rw"
          "/dev/rga rw"
          # MPP's DRM allocator opens the primary card node. The official
          # Rockchip guide exposes the whole /dev/dri directory, not only the
          # render nodes used by VA-API.
          "/dev/dri/card0 rw"
          "/dev/dri/card1 rw"
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
