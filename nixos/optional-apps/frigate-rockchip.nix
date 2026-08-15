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
  # 摄像头密码的 FRIGATE_* 环境变量名（占位符与 env 文件都以此命名）。
  pwVar = name: "FRIGATE_" + lib.toUpper (lib.replaceStrings [ "-" ] [ "_" ] name) + "_PW";
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
    model = lib.mkOption {
      type = lib.types.str;
      default = "deci-fp16-yolonas_s";
      description = "RKNN model preset (auto-downloaded) or path to a .rknn file";
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
              description = "RTSP URL; use the {FRIGATE_<NAME>_PW} placeholder for the local password";
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
        # 模型与镜像首次拉取/下载走 router SOCKS5 代理（与其它 opi5p
        # 工作负载一致）；内网地址与自有域直连。
        HTTP_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
        HTTPS_PROXY = "socks5://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
        NO_PROXY = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin";
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
      ];
    };

    systemd.services.podman-frigate = {
      # sops 渲染的 config.yml 必须先于容器启动存在。
      after = [ "sops-nix.service" ];
      wants = [ "sops-nix.service" ];
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
