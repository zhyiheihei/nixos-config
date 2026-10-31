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
        ports = [
          "127.0.0.1:${LT.portStr.Mcsm.Daemon}:24444"
          "25565:25565/tcp"
          "25565:25565/udp"
        ];
        environment = {
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
