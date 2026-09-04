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
  # 自制块状 YAML 发射器：lib.generators.toYAML 实为 toJSON，flow 风格
  # 会让 frigate 再转储 go2rtc 段时产出非法 YAML（详见 frigate-nvr 文档）。
  yamlQuote = s: "\"" + builtins.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s + "\"";
  toYaml =
    indent: v:
    if lib.isString v then
      yamlQuote v
    else if lib.isBool v then
      (if v then "true" else "false")
    else if lib.isInt v || builtins.isFloat v then
      toString v
    else if lib.isList v then
      if v == [ ] then
        "[]"
      else
        lib.concatMapStringsSep "\n" (
          item:
          if lib.isAttrs item && item != { } then
            "${indent}- " + lib.removePrefix "${indent}  " (toYaml "${indent}  " item)
          else
            "${indent}- " + toYaml "${indent}  " item
        ) v
    else if lib.isAttrs v then
      if v == { } then
        "{}"
      else
        lib.concatMapStringsSep "\n" (
          k:
          let
            val = v.${k};
          in
          if (lib.isAttrs val || lib.isList val) && val != { } && val != [ ] then
            "${indent}${yamlQuote k}:\n" + toYaml "${indent}  " val
          else
            "${indent}${yamlQuote k}: " + toYaml "${indent}  " val
        ) (lib.attrNames v)
    else
      throw "frigate config: unsupported value ${toString v}";
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
            # autotracking 触发区：多边形顶点坐标（"0.123,0.456,0.789,..."，
            # 归一化 0~1 平铺序列，相对 detect 帧尺寸）。空 attrs 表示不定义
            # zone；定义后供 requiredZones 引用。官方不推荐 autotracking 用全帧 zone。
            zones = lib.mkOption {
              type = lib.types.attrsOf (
                lib.types.submodule {
                  options = {
                    coordinates = lib.mkOption {
                      type = lib.types.str;
                      description = "Polygon vertices: \"x1,y1,x2,y2,...\" (normalized 0~1 flat comma-separated sequence relative to detect frame)";
                    };
                    inertia = lib.mkOption {
                      type = lib.types.int;
                      default = 3;
                    };
                  };
                }
              );
              default = { };
            };
            # PTZ 自动跟踪：靠 ONVIF 相对移动（RelativePanTiltTranslationSpace
            # 含 TranslationSpaceFov）实现，前提是摄像头云台支持该能力。
            # 本仓库两台乐橙（TA3R/DK2）实测不支持 RelativeMove（云台物理不
            # 移动、校准 slope≈0），故 opi5p 上不再启用，只保留手动 PTZ 与
            # 猫检测告警。此处选项保留供支持该能力的摄像头使用。
            autotracking = lib.mkOption {
              type = lib.types.nullOr (
                lib.types.submodule {
                  options = {
                    enabled = lib.mkEnableOption "PTZ autotracking for this camera";
                    returnPreset = lib.mkOption {
                      type = lib.types.str;
                      default = "home";
                      description = "ONVIF preset name to return to when tracking ends";
                    };
                    calibrateOnStartup = lib.mkOption {
                      type = lib.types.bool;
                      default = false;
                      description = "Calibrate PTZ motor speed on startup (moves camera ~2min)";
                    };
                    zooming = lib.mkOption {
                      type = lib.types.enum [
                        "disabled"
                        "absolute"
                        "relative"
                      ];
                      default = "disabled";
                    };
                    zoomFactor = lib.mkOption {
                      type = lib.types.number;
                      default = 0.3;
                    };
                    timeout = lib.mkOption {
                      type = lib.types.int;
                      default = 10;
                      description = "Seconds to delay before returning to preset";
                    };
                    track = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ "cat" ];
                      description = "Object types to autotrack (must also be in global objects.track)";
                    };
                    requiredZones = lib.mkOption {
                      type = lib.types.listOf lib.types.str;
                      default = [ ];
                      description = "Zones an object must enter to begin autotracking";
                    };
                  };
                }
              );
              default = null;
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
      lib.mapAttrsToList (name: _: {
        "frigate-${name}-pw" = {
          sopsFile = inputs.secrets + "/frigate.yaml";
          key = "${name}-pw";
          mode = "0444";
        };
      }) cfg.cameras
    );

    sops.templates."frigate-config" = {
      restartUnits = [ "podman-frigate.service" ];
      content = toYaml "" {
        version = "0.17-0";
        mqtt = {
          enabled = true;
          host = "127.0.0.1";
          port = 1883;
        };
        auth.enabled = false;
        proxy = {
          header_map = {
            user = "x-user";
            role = "x-groups";
          };
          default_role = "admin";
        };
        database.path = "/config/frigate.db";
        go2rtc.streams = lib.mapAttrs (_: cam: [ cam.rtspUrl ]) cfg.cameras;
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
        objects = {
          track = [ "cat" ];
          filters.cat = {
            threshold = 0.7;
            min_score = 0.5;
          };
        };
        classification.custom."毛豆" = {
          enabled = true;
          name = "毛豆";
          threshold = 0.8;
          object_config = {
            objects = [ "cat" ];
            classification_type = "sub_label";
          };
        };
        snapshots = {
          enabled = true;
          retain.default = cfg.retentionDays;
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
            }
            // lib.optionalAttrs (cam.autotracking != null) {
              autotracking = {
                enabled = cam.autotracking.enabled;
                return_preset = cam.autotracking.returnPreset;
                calibrate_on_startup = cam.autotracking.calibrateOnStartup;
                zooming = cam.autotracking.zooming;
                zoom_factor = cam.autotracking.zoomFactor;
                timeout = cam.autotracking.timeout;
                track = cam.autotracking.track;
                required_zones = cam.autotracking.requiredZones;
              };
            };
            # 只用定义过的 zone（自动跟踪 requiredZones 引用的区域）。
            inherit (cam) zones;
            detect.enabled = true;
            record.enabled = true;
          }
        ) cfg.cameras;
      };
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
        # 4K 主码流检测时 frigate 实测建议 /dev/shm ≥ 446MB（256MB 会告警）。
        "--shm-size=512m"
      ];
    };

    systemd.services.podman-frigate = {
      # sops 渲染的 config.yml 必须先于容器启动存在（sops 服务名是
      # sops-install-secrets.service，不是 sops-nix.service）。
      after = [ "sops-install-secrets.service" ];
      wants = [ "sops-install-secrets.service" ];
      serviceConfig.ExecStartPre = lib.mkBefore [
        (pkgs.writeShellScript "frigate-prepare" ''
          # sops 模板渲染结果是符号链接（容器内 /run 不同会断链），
          # 先删旧链接再装成真实文件。
          rm -f '${cfg.configDir}/config.yml'
          install -Dm644 /run/secrets/rendered/frigate-config '${cfg.configDir}/config.yml'
          # 预取的 RKNN 模型 → 模型缓存（frigate 按名查找，存在则跳过下载）。
          mkdir -p '${cfg.configDir}/model_cache/rknn_cache'
          if ! test -f '${cfg.configDir}/model_cache/rknn_cache/${modelFileName}'; then
            install -Dm644 '${modelFetch}' '${cfg.configDir}/model_cache/rknn_cache/${modelFileName}'
          fi
        '')
      ];
      environment = LT.proxyEnvironment // {
        NO_PROXY = "${LT.proxyBypass},docker.m.daocloud.io";
      };
    };

    systemd.tmpfiles.settings.frigate."${cfg.configDir}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    # 私有入口：仅内网可达（accessibleBy = private），HTTPS 用现成
    # *.<hostname>.zhyi.xin 通配证书。frigate 0.17 的 Web 是 HTTPS-only
    # （容器内自签证书），反代走 https 并关闭证书校验。
    lantian.nginxVhosts."frigate.${config.networking.hostName}.zhyi.xin" = {
      locations."/" = {
        proxyPass = "https://127.0.0.1:${LT.portStr.Frigate}";
        extraConfig = ''
          proxy_ssl_verify off;
          proxy_ssl_server_name off;
        '';
        proxyWebsockets = true;
        proxyNoTimeout = true;
        enableOAuth = true;
      };
      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
    };
  };
}
