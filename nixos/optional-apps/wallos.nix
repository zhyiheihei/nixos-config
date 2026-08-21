{
  LT,
  config,
  inputs,
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
    sops.secrets.dex-wallos-secret = {
      sopsFile = inputs.secrets + "/common/dex.yaml";
      owner = "root";
      group = "root";
    };

    sops.templates.wallos-oidc-env.content = ''
      OIDC_CLIENT_SECRET=${config.sops.placeholder.dex-wallos-secret}
    '';

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
        # OIDC via Dex (login.zhyi.xin) -> Pocket ID. Issuer auto-discovers
        # auth/token/userinfo endpoints from .well-known.
        OIDC_ENABLED = "true";
        OIDC_PROVIDER_NAME = "Dex";
        OIDC_ISSUER = "https://login.zhyi.xin";
        OIDC_CLIENT_ID = "wallos";
        OIDC_REDIRECT_URL = "https://wallos.${config.networking.hostName}.zhyi.xin/index.php";
        OIDC_SCOPES = "openid profile email";
        OIDC_USER_IDENTIFIER = "preferred_username";
        OIDC_AUTO_CREATE_USER = "true";
        OIDC_DISABLE_PASSWORD_LOGIN = "false";
      };
      environmentFiles = [ config.sops.templates.wallos-oidc-env.path ];
    };

    # podman bind-mounts require the source dirs to already exist; create the
    # per-volume subdirs (db, logos) that Wallos mounts explicitly.
    systemd.tmpfiles.settings.wallos."${config.lantian.wallos.storage}"."d" = {
      mode = "0750";
      user = "root";
      group = "root";
    };
    systemd.tmpfiles.settings.wallos-db."${config.lantian.wallos.storage}/db"."d" = {
      mode = "0750";
      user = "root";
      group = "root";
    };
    systemd.tmpfiles.settings.wallos-logos."${config.lantian.wallos.storage}/logos"."d" = {
      mode = "0750";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts."wallos.${config.networking.hostName}.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Wallos}";
        proxyNoTimeout = true;
      };
      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
    };
  };
}
