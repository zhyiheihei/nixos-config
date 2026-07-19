{
  LT,
  config,
  inputs,
  lib,
  ...
}:
{
  options.lantian.freshrss.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/freshrss";
    description = "Storage path for FreshRSS data";
  };

  config = {
    sops.secrets = {
      freshrss-oidc-client-secret = {
        sopsFile = inputs.secrets + "/common/dex.yaml";
        key = "dex-freshrss-secret";
      };
      freshrss-oidc-client-crypto-key = {
        sopsFile = inputs.secrets + "/common/personal-apps.yaml";
        key = "FRESHRSS_OIDC_CLIENT_CRYPTO_KEY";
      };
    };

    sops.templates.freshrss-env.content = ''
      OIDC_CLIENT_SECRET=${config.sops.placeholder.freshrss-oidc-client-secret}
      OIDC_CLIENT_CRYPTO_KEY=${config.sops.placeholder.freshrss-oidc-client-crypto-key}
    '';

    virtualisation.oci-containers.containers.freshrss = {
      image = "docker.io/freshrss/freshrss:1.29.1";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.FreshRSS}:80" ];
      volumes = [
        "${config.lantian.freshrss.storage}/www/freshrss/data:/var/www/FreshRSS/data"
        "${config.lantian.freshrss.storage}/www/freshrss/extensions:/var/www/FreshRSS/extensions"
      ];
      environment = {
        TZ = config.time.timeZone;
        OIDC_ENABLED = "1";
        OIDC_PROVIDER_METADATA_URL = "https://login.zhyi.xin/.well-known/openid-configuration";
        OIDC_CLIENT_ID = "freshrss";
        OIDC_REMOTE_USER_CLAIM = "preferred_username";
        OIDC_SCOPES = "openid profile email groups";
        OIDC_X_FORWARDED_HEADERS = "X-Forwarded-Host X-Forwarded-Port X-Forwarded-Proto";
      };
      environmentFiles = [ config.sops.templates.freshrss-env.path ];
    };

    systemd.tmpfiles.settings.freshrss."${config.lantian.freshrss.storage}"."d" = {
      mode = "0755";
      user = "1000";
      group = "1000";
    };

    lantian.nginxVhosts = {
      "freshrss.${config.networking.hostName}.zhyi.cc" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.FreshRSS}";
          enableOAuth = true;
        };
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
