{ LT, config, lib, ... }:
{
  options.lantian.vertex.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/vertex";
    description = "Storage path for Vertex data";
  };

  config = {
    virtualisation.oci-containers.containers.vertex = {
      image = "docker.io/lswl/vertex:stable";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.Vertex}:3000" ];
      volumes = [ "${config.lantian.vertex.storage}:/vertex" ];
      environment.TZ = config.time.timeZone;
    };

    systemd.tmpfiles.settings.vertex."${config.lantian.vertex.storage}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts = {
      "vertex.${config.networking.hostName}.zhyi.cc" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.Vertex}";
          enableOAuth = true;
        };
        accessibleBy = "private";
        sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
        noIndex.enable = true;
      };
      "vertex.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.Vertex}";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
  };
}
