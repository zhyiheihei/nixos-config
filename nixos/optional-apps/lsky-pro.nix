{
  config,
  lib,
  LT,
  ...
}:
let
  cfg = config.lantian.lskyPro;
in
{
  options.lantian.lskyPro = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
    };
  };

  config = lib.mkIf cfg.enable {
    # Official Docker image (FrankenPHP + libvips, bundled queue/scheduler).
    # First visit to the web UI runs the graphical installer; SQLite is
    # created automatically, no external MySQL needed.
    virtualisation.oci-containers.containers.lsky-pro = {
      image = "0xxb/lsky-pro:latest";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.LskyPro}:8000" ];
      volumes = [
        "/var/lib/lsky-pro:/app/storage/app"
        "/var/lib/lsky-pro/themes:/app/themes"
      ];
    };

    systemd.tmpfiles.settings = {
      lsky-pro = {
        "/var/lib/lsky-pro"."d" = {
          mode = "755";
          user = "root";
          group = "root";
        };
        "/var/lib/lsky-pro/themes"."d" = {
          mode = "755";
          user = "root";
          group = "root";
        };
      };
    };

    # Public entry: pic.zhyi.xin, wildcard cert synced from greencloud.
    lantian.nginxVhosts."pic.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.LskyPro}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };
      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
