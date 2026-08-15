{
  config,
  lib,
  LT,
  inputs,
  pkgs,
  ...
}:
{
  # 两台乐橙（华橙网络）摄像头的本地密码来自私有 secrets flake。密码只经
  # sops 解密到 /run/secrets，再渲染成 frigate 服务的 EnvironmentFile，最后
  # 由 Frigate 启动时的 {FRIGATE_*} 占位符替换进 frigate.yml——任何一步都
  # 不落进 Nix store。
  sops.secrets."frigate-bedroom-pw" = {
    sopsFile = inputs.secrets + "/frigate.yaml";
    key = "bedroom-pw";
    mode = "0444";
  };
  sops.secrets."frigate-livingroom-pw" = {
    sopsFile = inputs.secrets + "/frigate.yaml";
    key = "livingroom-pw";
    mode = "0444";
  };
  sops.templates."frigate-env" = {
    content = ''
      FRIGATE_BEDROOM_PW=${config.sops.placeholder."frigate-bedroom-pw"}
      FRIGATE_LIVINGROOM_PW=${config.sops.placeholder."frigate-livingroom-pw"}
    '';
    path = "/run/frigate-env";
    owner = "frigate";
    group = "frigate";
    mode = "0400";
  };

  services.frigate = {
    enable = true;
    # nixpkgs 的 frigate 模块会自带一个 nginx vhost 处理 /auth、/vod、/live
    # 等内部路径；只让它监听回环端口，公网入口由下面 lantian.nginxVhosts
    # 的私有 vhost 转发过来。
    hostname = "frigate.localhost";
    settings = {
      # 录像在 NAS（/var/lib/frigate 由 ExecStartPre bind 到 /mnt/storage/
      # surveillance/frigate），SQLite 数据库留在本机持久化 NVMe，避免 NFS
      # 上锁文件带来的风险。
      database.path = "/nix/persistent/var/lib/frigate/frigate.db";

      detectors.cpu = {
        type = "cpu";
      };

      # 连续录像 7 天；告警与检测片段同样保留 7 天。
      record = {
        enabled = true;
        continuous.days = 7;
        alerts.retain.days = 7;
        detections.retain.days = 7;
      };

      cameras = {
        bedroom = {
          ffmpeg.inputs = [
            {
              path = "rtsp://admin:{FRIGATE_BEDROOM_PW}@192.168.0.104:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
              roles = [
                "detect"
                "record"
              ];
            }
          ];
          onvif = {
            host = "192.168.0.104";
            port = 80;
            user = "admin";
            password = "{FRIGATE_BEDROOM_PW}";
          };
          detect.enabled = true;
          record.enabled = true;
        };
        livingroom = {
          ffmpeg.inputs = [
            {
              path = "rtsp://admin:{FRIGATE_LIVINGROOM_PW}@192.168.0.115:554/cam/realmonitor?channel=1&subtype=0&unicast=true&proto=Onvif";
              roles = [
                "detect"
                "record"
              ];
            }
          ];
          onvif = {
            host = "192.168.0.115";
            port = 80;
            user = "admin";
            password = "{FRIGATE_LIVINGROOM_PW}";
          };
          detect.enabled = true;
          record.enabled = true;
        };
      };
    };
  };

  # 模块自带的 nginx vhost 只监听回环端口，避免与项目里 0.0.0.0:80 的
  # 公共 vhost 抢同一监听套接字。
  services.nginx.virtualHosts."frigate.localhost".listen = lib.mkForce [
    {
      addr = "127.0.0.1";
      port = LT.port.Frigate;
    }
  ];

  # 私有入口：仅内网可达（accessibleBy = private），HTTP-only，参考
  # tachidesk-backend.opi5p.zhyi.cc 的做法，不对外公开。
  lantian.nginxVhosts."frigate.${config.networking.hostName}.zhyi.cc" = {
    listenHTTP.enable = true;
    listenHTTPS.enable = false;
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Frigate}";
      proxyOverrideHost = "frigate.localhost";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    accessibleBy = "private";
    noIndex.enable = true;
  };

  systemd.services.frigate = {
    serviceConfig.EnvironmentFile = lib.mkAfter [ "-/run/frigate-env" ];
    # NFS 挂载由模块之外声明（_netdev），frigate 启动时通常已就绪；这里以
    # root（+ 前缀）把录像目录 bind 到 NAS 路径并修正所有权。NFS 不可用时
    # mkdir 会在根文件系统上兜底，服务降级运行而不是起不来。
    serviceConfig.ExecStartPre = lib.mkAfter [
      "+${pkgs.writeShellScript "frigate-bind-nas-recordings" ''
        mkdir -p /mnt/storage/surveillance/frigate
        if ! mountpoint -q /var/lib/frigate; then
          mount --bind /mnt/storage/surveillance/frigate /var/lib/frigate
        fi
        chown frigate:frigate /var/lib/frigate
      ''}"
    ];
  };

  # SQLite 数据库目录：本机持久化 NVMe。
  systemd.tmpfiles.settings.frigate."/nix/persistent/var/lib/frigate"."d" = {
    mode = "0700";
    user = "frigate";
    group = "frigate";
  };
}
