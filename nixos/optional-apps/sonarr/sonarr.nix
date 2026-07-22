{
  LT,
  config,
  lib,
  ...
}:
{
  services.sonarr = {
    enable = true;
    user = "zhyi";
    group = "users";
    dataDir = "/var/lib/sonarr";
  };
  systemd.services.sonarr = {
    serviceConfig = LT.serviceHarden // {
      RestrictAddressFamilies = [
        "AF_INET"
        "AF_INET6"
        "AF_UNIX"
        "AF_NETLINK"
      ];
      StateDirectory = "sonarr";
      MemoryDenyWriteExecute = false;
    };
  };

  lantian.nginxVhosts = {
    "sonarr.${config.networking.hostName}.zhyi.cc" = {
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.Sonarr}";
        };
      };

      sslCertificate = "zerossl-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
      accessibleBy = "private";
    };
    "sonarr.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.Sonarr}";
        };
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };

  services.prometheus.exporters.exportarr-sonarr = {
    enable = true;
    listenAddress = LT.this.ltnet.IPv4;
    port = LT.port.Prometheus.SonarrExporter;
    url = "http://sonarr.localhost";
    environment = {
      INTERFACE = LT.this.ltnet.IPv4;
      PORT = LT.portStr.Prometheus.SonarrExporter;
      CONFIG = "/var/lib/sonarr/config.xml";
    };
    inherit (config.services.sonarr) user group;
  };
  systemd.services.prometheus-exportarr-sonarr-exporter.serviceConfig = {
    DynamicUser = lib.mkForce false;
  };
}
