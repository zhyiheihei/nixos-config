{ LT, config, lib, ... }:
{
  options.lantian.filecodebox.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/filecodebox";
    description = "Storage path for FileCodeBox data";
  };

  config = {
    virtualisation.oci-containers.containers.filecodebox = {
      image = "docker.io/lanol/filecodebox:beta";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.FileCodeBox}:12345" ];
      volumes = [ "${config.lantian.filecodebox.storage}:/app/data" ];
      environment = {
        HOST = "0.0.0.0";
        PORT = "12345";
        WORKERS = "1";
        LOG_LEVEL = "info";
      };
    };

    systemd.tmpfiles.settings.filecodebox."${config.lantian.filecodebox.storage}"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts = {
      "filebox.zhyi.xin" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.FileCodeBox}";
          enableOAuth = true;
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "filebox.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.FileCodeBox}";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
  };
}
