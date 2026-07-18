{ LT, config, lib, ... }:
{
  options.lantian.freshrss.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/freshrss";
    description = "Storage path for FreshRSS data";
  };

  config = {
    virtualisation.oci-containers.containers.freshrss = {
      image = "docker.io/linuxserver/freshrss:1.29.1";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.FreshRSS}:80" ];
      volumes = [ "${config.lantian.freshrss.storage}:/config" ];
      environment = {
        PUID = "1000";
        PGID = "1000";
        TZ = config.time.timeZone;
      };
    };

    systemd.tmpfiles.settings.freshrss."${config.lantian.freshrss.storage}"."d" = {
      mode = "0755";
      user = "1000";
      group = "1000";
    };

    lantian.nginxVhosts = {
      "freshrss.${config.networking.hostName}.zhyi.cc" = {
        locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.FreshRSS}";
        accessibleBy = "private";
        sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
        noIndex.enable = true;
      };
      "freshrss.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.FreshRSS}";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
  };
}
