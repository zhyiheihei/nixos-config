{ LT, config, ... }:
{
  virtualisation.oci-containers.containers.archiveteam = {
    environment = {
      DOWNLOADER = "lantian";
      SELECTED_PROJECT = "auto";
    };
    labels."io.containers.autoupdate" = "registry";
    image = "atdr.meo.ws/archiveteam/warrior-dockerfile";
    ports = [ "127.0.0.1:${LT.portStr.ArchiveTeam}:8001" ];
    volumes = [ "/var/lib/archiveteam:/home/warrior/projects" ];
  };

  systemd.tmpfiles.settings = {
    archiveteam = {
      "/var/lib/archiveteam"."d" = {
        mode = "755";
        user = "1000";
        group = "1000";
      };
    };
  };

  lantian.nginxVhosts = {
    "archiveteam.${config.networking.hostName}.zhyi.cc" = {
      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.ArchiveTeam}";
        };
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "archiveteam.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations = {
        "/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.ArchiveTeam}";
        };
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };
}
