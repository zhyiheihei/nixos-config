{
  config,
  lib,
  LT,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.lantian.frigate;
  # 模型文件名（fr-frigate 预设模型的固定命名）：
  # <model>-<soc>-v2.3.2-2.rknn，frigate 的 rknn 插件按该名字在
  # model_cache/rknn_cache 下查找，不存在才去 GitHub 下载。
  modelFileName = "${cfg.model}-${cfg.soc}-v2.3.2-2.rknn";
  # 预设模型由 nix 预取（确定性、无运行时网络依赖）；自定义路径模型
  # （含 "/"）不预取，运行时需自行就位。
  modelFetch =
    if builtins.match "^[^/]+$" cfg.model != null then
      pkgs.fetchurl {
        url = "https://github.com/MarcA711/rknn-models/releases/download/v2.3.2-2/${modelFileName}";
        sha256 = cfg.modelHash;
      }
    else
      null;
in
{
  # 通用 Rockchip 专版 Frigate（官方 stable-rk 镜像，RKNN NPU 检测）。
  # 可在任何带 Rockchip BSP 内核 + rknpu 驱动的 RK 板（RK3566/3568/3588
  # 等）上启用：lubancat1、r5c（RK3588S）、rock5c、opi5p 均满足。
  options.lantian.frigate = {
    enable = lib.mkEnableOption "the Rockchip (RKNN) Frigate NVR container";

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/frigate";
      description = "Host directory bind-mounted into the container's /config (config.yml + sqlite db)";
    };
    mediaDir = lib.mkOption {
      type = lib.types.str;
      default = "/mnt/storage/surveillance/frigate";
      description = "Host directory bind-mounted into the container's /media/frigate (recordings)";
    };

    numCores = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "NPU cores for RKNN detection; 0 = auto, 3 on RK3588";
    };
    soc = lib.mkOption {
      type = lib.types.str;
      default = "rk3588";
      description = "Rockchip SoC for the RKNN model filename (rk3566/rk3568/rk3588/...)";
    };
    model = lib.mkOption {
      type = lib.types.str;
      default = "deci-fp16-yolonas_s";
      description = "RKNN model preset (auto-downloaded by nix) or path to a .rknn file";
    };
    modelHash = lib.mkOption {
      type = lib.types.str;
      default = "sha256-ytG/tXH7JJV2cv8PjftAOpZgGyYx2+87Puc7/y0Rt7g=";
      description = "SRI sha256 of the preset model (rk3588 deci-fp16-yolonas_s); update when changing model/soc";
    };
    modelType = lib.mkOption {
      type = lib.types.str;
      default = "yolonas";
      description = "Model type: yolonas / yolo-generic / yolox";
    };
    modelSize = lib.mkOption {
      type = lib.types.int;
      default = 320;
      description = "Model input size (square)";
    };
    retentionDays = lib.mkOption {
      type = lib.types.int;
      default = 7;
      description = "Continuous recording + alert/detection clip retention in days";
    };

    cameras = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            rtspUrl = lib.mkOption {
              type = lib.types.str;
              description = ''
                RTSP URL。密码用 sops 占位符：
                rtsp://admin:''${config.sops.placeholder."<camera>-pw"}@host/...
                （该占位符由 sops 模板渲染时替换为真实密码）
              '';
            };
            onvifHost = lib.mkOption {
              type = lib.types.str;
              description = "ONVIF host (camera IP)";
            };
            onvifPort = lib.mkOption {
              type = lib.types.port;
              default = 80;
            };
            onvifUser = lib.mkOption {
              type = lib.types.str;
              default = "admin";
            };
          };
        }
      );
      default = { };
      description = "Camera definitions; password secret key in secrets/frigate.yaml is <name>-pw";
    };
  };

  config = lib.mkIf cfg.enable {
    # 每个摄像头的本地密码来自私有 secrets flake（key = <camera>-pw），
    # 由 sops 模板直接渲染进 config.yml——密码不落 Nix store。
    sops.secrets = lib.mkMerge (
      lib.mapAttrsToList (
        name: _:
        {
          "frigate-${name}-pw" = {
            sopsFile = inputs.secrets + "/frigate.yaml";
            key = "${name}-pw";
            mode = "0444";
          };
        }
      ) cfg.cameras
    );

    # 整个 frigate.yml 由 sops 模板渲染（JSON 是合法 YAML），
    # 密码占位符在解密时替换。
    sops.templates."frigate-config" = {
      content = builtins.toJSON (
        {
          # frigate 0.17 起 mqtt 为必填字段（不开 MQTT，HA 集成走 HTTP API）。
          mqtt.enabled = false;
          database.path = "/config/frigate.db";
          detectors.rknn = {
            type = "rknn";
            num_cores = cfg.numCores;
            model = {
              path = cfg.model;
              model_type = cfg.modelType;
              width = cfg.modelSize;
              height = cfg.modelSize;
              input_pixel_format = "bgr";
              input_tensor = "nhwc";
              labelmap_path = "/labelmap/coco-80.txt";
            };
          };
          record = {
            enabled = true;
            continuous.days = cfg.retentionDays;
            alerts.retain.days = cfg.retentionDays;
            detections.retain.days = cfg.retentionDays;
          };
          cameras = lib.mapAttrs (
            name: cam:
            let
              pw = "${config.sops.placeholder."frigate-${name}-pw"}";
            in
            {
              ffmpeg.inputs = [
                {
                  path = cam.rtspUrl;
                  roles = [
                    "detect"
                    "record"
                  ];
                }
              ];
              onvif = {
                host = cam.onvifHost;
                port = cam.onvifPort;
                user = cam.onvifUser;
                password = pw;
              };
              detect.enabled = true;
              record.enabled = true;
            }
          ) cfg.cameras;
        }
      );
      # sops 渲染后这里是一个指向 /run/secrets/rendered/frigate-config 的
      # 符号链接；容器内 /run 是容器自己的，链接会断，所以 podman-frigate
      # 的 ExecStartPre 会把它复制成真实文件。
      path = "${cfg.configDir}/config.yml";
      owner = "root";
      group = "root";
      mode = "0644";
    };

    virtualisation.oci-containers.containers.frigate = {
      image = "ghcr.io/blakeblackshear/frigate:stable-rk";
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      environment = {
        TZ = config.time.timeZone;
        # 模型由 nix 预取，RTSP/ONVIF 走内网——容器内不需要代理。
        # （不给 frigate 配 socks5：其 urllib 模型下载不认 socks5。）
      };
      volumes = [
        "${cfg.configDir}:/config"
        "${cfg.mediaDir}:/media/frigate"
        # 官方 rockchip 安装要求挂载 /sys（设备树 get_soc 探测需要）。
        "/sys:/sys:ro"
      ];
      devices = [
        "/dev/dri:/dev/dri"
        "/dev/dma_heap:/dev/dma_heap"
        "/dev/rga:/dev/rga"
        "/dev/mpp_service:/dev/mpp_service"
      ];
      extraOptions = [
        # host 网络：frigate web(8971)/api(5000)/rtsp(8554)/go2rtc(1984)
        # 直接监听宿主机，nginx 私有 vhost 反代 8971。
        "--network=host"
        # 官方 rockchip 安装说明要求放宽 system paths / apparmor，
        # 否则容器内 /sys、/proc 探测被拒绝。
        "--security-opt=systempaths=unconfined"
        "--security-opt=apparmor=unconfined"
        # frigate 建议 /dev/shm ≥ 114MB（默认 62.5MB 会告警）。
        "--shm-size=256m"
      ];
    };

    systemd.services.podman-frigate = {
      # sops 渲染的 config.yml 必须先于容器启动存在（sops 服务名是
      # sops-install-secrets.service，不是 sops-nix.service）。
      after = [ "sops-install-secrets.service" ];
      wants = [ "sops-install-secrets.service" ];
      serviceConfig.ExecStartPre = lib.mkBefore [
        (pkgs.writeShellScript "frigate-prepare" ''
          # sops 模板渲染结果 → 真实 config.yml（容器内 /run 不同，符号链接会断）。
          install -Dm644 /run/secrets/rendered/frigate-config '${cfg.configDir}/config.yml'
          # 预取的 RKNN 模型 → 模型缓存（frigate 按名查找，存在则跳过下载）。
          mkdir -p '${cfg.configDir}/model_cache/rknn_cache'
          if ! test -f '${cfg.configDir}/model_cache/rknn_cache/${modelFileName}'; then
            install -Dm644 '${modelFetch}' '${cfg.configDir}/model_cache/rknn_cache/${modelFileName}'
          fi
        '')
      ];
      # 镜像拉取走 router 代理（与其它 opi5p 容器一致）。
      environment = {
        HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
        HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
        NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,docker.m.daocloud.io,.zhyi.cc,.zhyi.xin";
      };
    };

    systemd.tmpfiles.settings.frigate."${cfg.configDir}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    # 私有入口：仅内网可达（accessibleBy = private），HTTP-only。
    lantian.nginxVhosts."frigate.${config.networking.hostName}.zhyi.cc" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Frigate}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
      accessibleBy = "private";
      noIndex.enable = true;
    };
  };
}
