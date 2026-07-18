{ LT, config, ... }:
{
  virtualisation.oci-containers.containers.asf = {
    image = "ghcr.io/justarchinet/archisteamfarm:released";
    labels."io.containers.autoupdate" = "registry";
    environment.ASPNETCORE_URLS = "http://0.0.0.0:1242";
    ports = [ "${LT.this.ltnet.IPv4}:${LT.portStr.ASF}:1242" ];
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
          proxyPass = "http://${LT.this.ltnet.IPv4}:${LT.portStr.ASF}";
        };
        "~* /Api/NLog" = {
          enableOAuth = true;
          proxyPass = "http://${LT.this.ltnet.IPv4}:${LT.portStr.ASF}";
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
        "/".proxyPass = "http://${LT.this.ltnet.IPv4}:${LT.portStr.ASF}";
        "~* /Api/NLog" = {
          proxyPass = "http://${LT.this.ltnet.IPv4}:${LT.portStr.ASF}";
          proxyWebsockets = true;
        };
      };

      accessibleBy = "localhost";
      noIndex.enable = true;
    };
  };
}
