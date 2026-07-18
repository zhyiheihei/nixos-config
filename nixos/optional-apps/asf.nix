{ config, ... }:
{
  virtualisation.oci-containers.containers.asf = {
    image = "ghcr.io/justarchinet/archisteamfarm:released";
    labels."io.containers.autoupdate" = "registry";
    extraOptions = [ "--net=host" ];
    volumes = [
      "/var/lib/asf/config:/app/config"
      "/var/lib/asf/plugins:/app/plugins"
    ];
  };

  systemd.tmpfiles.settings = {
    asf = {
      "/var/lib/asf"."d" = {
        mode = "755";
        user = "1000";
        group = "1000";
      };
      "/var/lib/asf/config"."d" = {
        mode = "755";
        user = "1000";
        group = "1000";
      };
      "/var/lib/asf/plugins"."d" = {
        mode = "755";
        user = "1000";
        group = "1000";
      };
    };
  };

  lantian.nginxVhosts = {
    "asf.${config.networking.hostName}.zhyi.cc" = {
      locations = {
        "/" = {
          enableOAuth = true;
          proxyPass = "http://127.0.0.1:1242";
        };
        "~* /Api/NLog" = {
          enableOAuth = true;
          proxyPass = "http://127.0.0.1:1242";
          proxyWebsockets = true;
        };
      };

      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "asf.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations = {
        "/".proxyPass = "http://127.0.0.1:1242";
        "~* /Api/NLog" = {
          proxyPass = "http://127.0.0.1:1242";
          proxyWebsockets = true;
        };
      };

      accessibleBy = "localhost";
      noIndex.enable = true;
    };
  };
}
