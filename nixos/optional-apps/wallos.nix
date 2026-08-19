{
  LT,
  config,
  lib,
  ...
}:
{
  options.lantian.wallos = {
    enable = lib.mkEnableOption "Wallos subscription tracker";
    storage = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/wallos";
      description = "Root path for Wallos DB and logo uploads";
    };
  };

  config = lib.mkIf config.lantian.wallos.enable {
    virtualisation.oci-containers.containers.wallos = {
      image = "docker.io/bellamy/wallos:latest";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.Wallos}:80" ];
      volumes = [
        "${config.lantian.wallos.storage}/db:/var/www/html/db"
        "${config.lantian.wallos.storage}/logos:/var/www/html/images/uploads/logos"
      ];
      environment = {
        TZ = config.time.timeZone;
      };
    };

    systemd.tmpfiles.settings.wallos."${config.lantian.wallos.storage}"."d" = {
      mode = "0750";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts."wallos.${config.networking.hostName}.zhyi.cc" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Wallos}";
        proxyNoTimeout = true;
      };
      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
  };
}
