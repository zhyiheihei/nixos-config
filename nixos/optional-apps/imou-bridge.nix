{
  config,
  lib,
  LT,
  inputs,
  pkgs,
  ...
}:
let
  cfg = config.lantian.imouBridge;
  bridge = inputs.zhyi-packages.packages.${pkgs.system}.imou-bridge;
in
{
  # Imou/乐橙 P2P 桥接：家用乐橙摄像头本地 RTSP 被锁死（App 无开关、ONVIF
  # 正常但 554 拒绝连接），桥接用乐橙账号走云 DHP2P 中继，由 go2rtc 在局域网
  # 转出标准 RTSP/WebRTC，供 Frigate / Home Assistant 消费。
  options.lantian.imouBridge = {
    enable = lib.mkEnableOption "the Imou/Lechange P2P bridge (go2rtc restream)";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/imou-bridge";
      description = "Bridge state: options.json (账号/摄像头配置) + go2rtc.yaml + status.json";
    };
    # 与 frigate 容器自带 go2rtc（8554/1984/8555）错开端口。
    rtspPort = lib.mkOption {
      type = lib.types.port;
      default = 8654;
      description = "go2rtc RTSP restream port";
    };
    apiPort = lib.mkOption {
      type = lib.types.port;
      default = 1985;
      description = "go2rtc API/UI port";
    };
    webrtcPort = lib.mkOption {
      type = lib.types.port;
      default = 8655;
      description = "go2rtc WebRTC port";
    };
    uiPort = lib.mkOption {
      type = lib.types.port;
      default = 8099;
      description = "Bridge management UI port (账号登录 + 启用摄像头)";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.imou-bridge = {
      description = "Imou/Lechange P2P bridge (go2rtc restream)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];

      environment = {
        IMOU_BRIDGE_OPTIONS = "${cfg.dataDir}/options.json";
        IMOU_GO2RTC_CONFIG = "${cfg.dataDir}/go2rtc.yaml";
        IMOU_GO2RTC_BIN = "${bridge}/bin/go2rtc";
        IMOU_BRIDGE_STATUS = "${cfg.dataDir}/status.json";
        PYTHONPATH = "${bridge}/opt/imou-p2p-bridge";
      };
      # 用 path 选项扩展 PATH（自动保留 systemd 默认路径）。
      path = [
        bridge.pythonEnv
        pkgs.ffmpeg-headless
      ];

      # 首次启动写入带 go2rtc 端口配置的 options.json（UI 会继续往里写账号/摄像头）。
      preStart = ''
        mkdir -p '${cfg.dataDir}'
        if ! test -f '${cfg.dataDir}/options.json'; then
          cat > '${cfg.dataDir}/options.json' <<'EOF'
          ${builtins.toJSON {
            go2rtc = {
              rtsp_port = cfg.rtspPort;
              api_port = cfg.apiPort;
              webrtc_port = cfg.webrtcPort;
            };
          }}
          EOF
        fi
      '';

      serviceConfig = {
        ExecStart = "${bridge.pythonEnv}/bin/python ${bridge}/opt/imou-p2p-bridge/supervisor.py";
        Restart = "on-failure";
        RestartSec = 5;
      };
    };

    systemd.tmpfiles.settings.imou-bridge."${cfg.dataDir}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    # 管理 UI：仅内网（账号登录含 Geetest 滑块，需浏览器操作）。
    lantian.nginxVhosts."imou-bridge.${config.networking.hostName}.zhyi.cc" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.uiPort}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
      accessibleBy = "private";
      noIndex.enable = true;
    };
  };
}
