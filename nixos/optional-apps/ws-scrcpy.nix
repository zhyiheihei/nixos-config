{
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  cfg = config.lantian.ws-scrcpy;
in
{
  # ws-scrcpy：网页版 scrcpy，浏览器里镜像/控制 Android 设备。
  # 上游 NetrisTV/ws-scrcpy 已停更（最后 release v0.8.1，2024-03），无官方镜像。
  # 社区镜像多数只有 x86_64（scavin 等），这里用 docker.io/amu1680c/ws-scrcpy：
  # 多架构（amd64/arm64）、仅 dist+node_modules、以 node 用户运行、自带 adb，监听 8000。
  # 仅支持 TCP adb（无线/容器设备）；物理设备走 USB 需另挂 /dev/bus/usb，当前不涉及。
  # adb 连接状态存在容器内 adb server 里，容器重启即丢，靠定时器重连。
  options.lantian.ws-scrcpy = {
    enable = lib.mkEnableOption "the ws-scrcpy web-based scrcpy container";

    image = lib.mkOption {
      type = lib.types.str;
      default = "docker.io/amu1680c/ws-scrcpy:latest";
      description = "Container image; upstream publishes no official image.";
    };

    adbHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Remote adb endpoints (host:port, e.g. reDroid LAN IP:5555) to connect into the container's adb server.";
    };
  };

  config = lib.mkIf cfg.enable {
    virtualisation.oci-containers.containers.ws-scrcpy = {
      inherit (cfg) image;
      autoStart = true;
      labels."io.containers.autoupdate" = "registry";
      # 本机监听，经 nginx vhost 对外；镜像固定监听 8000
      ports = [ "127.0.0.1:${LT.portStr.WsScrcpy}:8000" ];
    };

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
  };
}
