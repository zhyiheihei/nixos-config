{
  LT,
  config,
  inputs,
  lib,
  ...
}:
{
  imports = [ ./postgresql.nix ];

  sops.secrets = {
    linkwarden-nextauth-secret = {
      sopsFile = inputs.secrets + "/common/personal-apps.yaml";
      key = "LINKWARDEN_NEXTAUTH_SECRET";
    };
    linkwarden-openai-api-key = {
      sopsFile = inputs.secrets + "/common/personal-apps.yaml";
      key = "LINKWARDEN_OPENAI_API_KEY";
    };
    linkwarden-oidc-client-secret = {
      sopsFile = inputs.secrets + "/common/dex.yaml";
      key = "dex-linkwarden-secret";
    };
  };

  sops.templates.linkwarden-env.content = ''
    DATABASE_URL=postgresql://linkwarden@localhost/linkwarden?host=/run/postgresql
    NEXTAUTH_SECRET=${config.sops.placeholder.linkwarden-nextauth-secret}
    OPENAI_API_KEY=${config.sops.placeholder.linkwarden-openai-api-key}
    OIDC_CLIENT_SECRET=${config.sops.placeholder.linkwarden-oidc-client-secret}
  '';

  services.postgresql = {
    ensureDatabases = [ "linkwarden" ];
    ensureUsers = [
      {
        name = "linkwarden";
        ensureDBOwnership = true;
      }
    ];
  };

  virtualisation.oci-containers.containers.linkwarden = {
    extraOptions = [
      "--uidmap=0:65531:1"
      "--gidmap=0:65531:1"
    ];
    image = "ghcr.io/linkwarden/linkwarden:latest";
    labels."io.containers.autoupdate" = "registry";
    ports = [ "127.0.0.1:${LT.portStr.Linkwarden}:3000" ];
    volumes = [
      "/var/lib/linkwarden:/app/data"
      "/run/postgresql:/run/postgresql"
    ];
    environment = {
      NEXTAUTH_URL = "https://linkwarden.${config.networking.hostName}.zhyi.cc/api/v1/auth";
      NEXT_PUBLIC_OIDC_ENABLED = "true";
      OIDC_CLIENT_ID = "linkwarden";
      OIDC_CUSTOM_NAME = "Dex";
      OIDC_SCOPES = "openid email profile groups";
      OIDC_WELLKNOWN_URL = "https://login.zhyi.xin/.well-known/openid-configuration";
      CUSTOM_OPENAI_BASE_URL = "https://ark.cn-beijing.volces.com/api/v3";
      OPENAI_MODEL = "doubao-1-5-lite-32k-250115";
    };
    environmentFiles = [ config.sops.templates.linkwarden-env.path ];
  };

  systemd.tmpfiles.settings.linkwarden."/var/lib/linkwarden"."d" = {
    mode = "0755";
    user = "linkwarden";
    group = "linkwarden";
  };

  systemd.services.podman-linkwarden = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  users.users.linkwarden = {
    group = "linkwarden";
    isSystemUser = true;
    uid = 65531;
  };
  users.groups.linkwarden.gid = 65531;

  lantian.nginxVhosts = {
    "linkwarden.${config.networking.hostName}.zhyi.cc" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Linkwarden}";
        proxyWebsockets = true;
        enableOAuth = true;
      };
      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
      noIndex.enable = true;
    };
    "linkwarden.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Linkwarden}";
        proxyWebsockets = true;
      };
      accessibleBy = "localhost";
      noIndex.enable = true;
    };
  };
}
