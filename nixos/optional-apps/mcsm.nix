{
  config,
  lib,
  LT,
  ...
}:
let
  cfg = config.lantian.mcsm;
in
{
  options.lantian.mcsm.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
  };

  config = lib.mkIf cfg.enable {
    # MCSManager 官方 Docker 部署（docs.mcsmanager.com/docker-install.html）：
    # web 面板 + daemon 两个容器，daemon 经 docker.sock 创建游戏实例容器。
    virtualisation.oci-containers.containers = {
      mcsm-web = {
        image = "docker.io/githubyumao/mcsmanager-web:latest";
        labels."io.containers.autoupdate" = "registry";
        ports = [ "127.0.0.1:${LT.portStr.Mcsm.Web}:23333" ];
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "/var/lib/mcsm/web/data:/opt/mcsmanager/web/data"
          "/var/lib/mcsm/web/logs:/opt/mcsmanager/web/logs"
          "/var/lib/mcsm/web/public/upload_files:/opt/mcsmanager/web/public/upload_files"
        ];
      };
      mcsm-daemon = {
        image = "docker.io/githubyumao/mcsmanager-daemon:latest";
        labels."io.containers.autoupdate" = "registry";
        ports = [ "127.0.0.1:${LT.portStr.Mcsm.Daemon}:24444" ];
        environment = {
          # docker.sock 创建实例容器时 -v 绑定按宿主机路径解析，须用宿主机路径
          MCSM_DOCKER_WORKSPACE_PATH = "/var/lib/mcsm/daemon/data/InstanceData";
        };
        volumes = [
          "/etc/localtime:/etc/localtime:ro"
          "/var/lib/mcsm/daemon/data:/opt/mcsmanager/daemon/data"
          "/var/lib/mcsm/daemon/logs:/opt/mcsmanager/daemon/logs"
          "/var/run/docker.sock:/var/run/docker.sock"
        ];
      };
    };

    systemd.tmpfiles.settings.mcsm = {
      "/var/lib/mcsm"."d" = {
        mode = "0700";
        user = "root";
        group = "root";
      };
      "/var/lib/mcsm/web/data"."d" = { };
      "/var/lib/mcsm/web/logs"."d" = { };
      "/var/lib/mcsm/web/public/upload_files"."d" = { };
      "/var/lib/mcsm/daemon/data"."d" = { };
      "/var/lib/mcsm/daemon/logs"."d" = { };
    };

    # 浏览器须直连 daemon（控制台/文件传输不经过 web 面板），HTTPS 反代时
    # daemon 也要有独立 TLS vhost，官方 docs.mcsmanager.com/ops/mcsm_network.html
    lantian.nginxVhosts = {
      "mcsm.zhyi.xin" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.Mcsm.Web}";
          proxyWebsockets = true;
        };

        sslCertificate = "zerossl-zhyi.xin";
        noIndex.enable = true;
      };
      "mcsm-daemon.zhyi.xin" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.Mcsm.Daemon}";
          proxyWebsockets = true;
          proxyNoTimeout = true;
        };

        sslCertificate = "zerossl-zhyi.xin";
        noIndex.enable = true;
      };
    };
  };
}
