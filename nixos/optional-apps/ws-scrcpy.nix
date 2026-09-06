{
  config,
  lib,
  LT,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.lantian.ws-scrcpy;
in
{
  # ws-scrcpy：网页版 scrcpy，浏览器里镜像/控制 Android 设备。
  # 包本体在 zhyi-packages（buildNpmPackage，x86_64/aarch64 双端编译），
  # 补丁加 WS_SCRCPY_BIND_HOST 绑定地址；Podman 容器保留为回退后端
  # （package = null 时启用，社区镜像 docker.io/amu1680c/ws-scrcpy）。
  options.lantian.ws-scrcpy = {
    enable = lib.mkEnableOption "the ws-scrcpy web-based scrcpy server";

    package = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = inputs.zhyi-packages.packages.${pkgs.system}.ws-scrcpy;
      defaultText = "zhyi-packages.ws-scrcpy";
      description = "Native package; set to null to fall back to the Podman container backend.";
    };

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/amu1680c/ws-scrcpy:latest";
      description = "Container image for the fallback backend.";
    };

    adbHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Remote adb endpoints (host:port, e.g. reDroid LAN IP:5555) to connect; connection state lives in the adb server and is re-established by timer.";
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        # 内网私有服务，OAuth（Dex）保护
        lantian.nginxVhosts."scrcpy.${config.networking.hostName}.zhyi.xin" = {
          locations."/" = {
            enableOAuth = true;
            proxyPass = "http://127.0.0.1:${LT.portStr.WsScrcpy}";
            proxyWebsockets = true;
            proxyNoTimeout = true;
          };
          accessibleBy = "private";
          sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
          noIndex.enable = true;
        };

        # 容器定义常驻（oci-containers 求值需要 image 有值），仅容器后端启动；
        # 容器镜像固定监听 8000，映射到登记端口 8421
        virtualisation.oci-containers.containers.ws-scrcpy = {
          inherit (cfg) image;
          autoStart = cfg.package == null;
          labels."io.containers.autoupdate" = "registry";
          ports = [ "127.0.0.1:${LT.portStr.WsScrcpy}:8000" ];
        };
      }

      # 原生后端：systemd 直跑 zhyi-packages 的包，绑 127.0.0.1
      (lib.mkIf (cfg.package != null) {
        systemd.services.ws-scrcpy = {
          description = "ws-scrcpy web-based scrcpy server";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          environment = {
            TZ = config.time.timeZone;
            # 上游裸听全部接口会绕过 nginx OAuth 入口，补丁收窄到本机
            WS_SCRCPY_BIND_HOST = "127.0.0.1";
            # 上游默认端口 8000，对齐登记端口 8421（与容器后端回源一致）
            WS_SCRCPY_CONFIG = pkgs.writeText "ws-scrcpy.yaml" ''
              server:
                - secure: false
                  port: ${LT.portStr.WsScrcpy}
            '';
          };
          serviceConfig = {
            Type = "simple";
            ExecStart = "${cfg.package}/bin/ws-scrcpy";
            StateDirectory = "ws-scrcpy";
            WorkingDirectory = "/var/lib/ws-scrcpy";
            Restart = "on-failure";
            RestartSec = "5s";
          };
        };

        # 关掉容器后端定义，避免两个后端同时抢 8421
        virtualisation.oci-containers.containers.ws-scrcpy.autoStart = lib.mkForce false;
        systemd.services.podman-ws-scrcpy.enable = lib.mkForce false;

        systemd.services.ws-scrcpy-adb-connect = lib.mkIf (cfg.adbHosts != [ ]) {
          description = "Connect remote adb devices for ws-scrcpy";
          wants = [ "ws-scrcpy.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "ws-scrcpy-adb-connect" ''
              # 与 ws-scrcpy 服务共享 root 的 adb server（:5037），
              # connect 状态存 server 里，设备/服务重启后由本定时器重建
              ${lib.concatMapStringsSep "\n" (host: ''
                ${pkgs.android-tools}/bin/adb connect "${host}" >/dev/null 2>&1 || true
              '') cfg.adbHosts}
            '';
          };
        };

        systemd.timers.ws-scrcpy-adb-connect = lib.mkIf (cfg.adbHosts != [ ]) {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "2min";
          };
        };
      })

      # 容器回退后端：镜像自带 adb，容器内 adb server 存连接状态
      (lib.mkIf (cfg.package == null) {
        systemd.services.ws-scrcpy-adb-connect = lib.mkIf (cfg.adbHosts != [ ]) {
          description = "Connect remote adb devices into the ws-scrcpy container";
          wants = [ "podman-ws-scrcpy.service" ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = pkgs.writeShellScript "ws-scrcpy-adb-connect" ''
              # 容器刚拉起时 adb server 未就绪，先等它应答
              for attempt in $(${pkgs.coreutils}/bin/seq 1 30); do
                ${config.virtualisation.podman.package}/bin/podman exec ws-scrcpy adb start-server >/dev/null 2>&1 && break
                ${pkgs.coreutils}/bin/sleep 2
              done
              ${lib.concatMapStringsSep "\n" (host: ''
                ${config.virtualisation.podman.package}/bin/podman exec ws-scrcpy adb connect "${host}" >/dev/null 2>&1 || true
              '') cfg.adbHosts}
            '';
          };
        };

        systemd.timers.ws-scrcpy-adb-connect = lib.mkIf (cfg.adbHosts != [ ]) {
          wantedBy = [ "timers.target" ];
          timerConfig = {
            OnBootSec = "1min";
            OnUnitActiveSec = "2min";
          };
        };
      })
    ]
  );
}
