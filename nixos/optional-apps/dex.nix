{
  pkgs,
  lib,
  LT,
  utils,
  config,
  inputs,
  ...
}:
let
  cfg = {
    issuer = "https://login.zhyi.xin";
    storage = {
      type = "postgres";
      config.host = "/run/postgresql";
    };
    web.http = "127.0.0.1:${LT.portStr.Dex}";
    oauth2 = {
      responseTypes = [
        "code"
        "token"
        "id_token"
      ];
      skipApprovalScreen = true;
      alwaysShowLoginScreen = false;
    };
    connectors = [
      {
        type = "oidc";
        name = "Pocket ID";
        id = "ldap"; # Backwards compatibility
        config = {
          issuer = "https://id.zhyi.xin";
          scopes = [
            "email"
            "profile"
            "groups"
            "offline_access"
          ];
          clientID = {
            _secret = config.sops.secrets.dex-pocket-id-client-id.path;
          };
          clientSecret = {
            _secret = config.sops.secrets.dex-pocket-id-client-secret.path;
          };
          redirectURI = "https://login.zhyi.xin/callback";
          insecureSkipEmailVerified = true;
          insecureEnableGroups = true;
          getUserInfo = true;
        };
      }
    ];
    staticClients = [
      # keep-sorted start block=yes
      {
        id = "gitea";
        name = "Gitea";
        secret = {
          _secret = config.sops.secrets.dex-gitea-secret.path;
        };
        redirectURIs = [ "https://git.zhyi.xin/user/oauth2/Dex/callback" ];
      }
      {
        id = "grafana";
        name = "Grafana";
        secret = {
          _secret = config.sops.secrets.dex-grafana-secret.path;
        };
        redirectURIs = [ "https://dashboard.zhyi.cc/login/generic_oauth" ];
      }
      {
        id = "immich";
        name = "Immich";
        secret = {
          _secret = config.sops.secrets.dex-immich-secret.path;
        };
        redirectURIs = [
          "https://immich.zhyi.xin/auth/login"
          "https://immich.zhyi.xin/user-settings"
          "https://immich.zhyi.xin/api/oauth/mobile-redirect"
          "app.immich:///oauth-callback"
        ];
      }
      {
        id = "librechat";
        name = "Librechat";
        secret = {
          _secret = config.sops.secrets.dex-librechat-secret.path;
        };
        redirectURIs = [ "https://ai.zhyi.xin/oauth/openid/callback" ];
      }
      {
        id = "oauth-proxy";
        name = "OAuth2 Proxy";
        secret = {
          _secret = config.sops.secrets.dex-oauth2-proxy-secret.path;
        };
        redirectURIs = [
          "https://*.zhyi.xin/oauth2/callback"
          "https://*.*.zhyi.xin/oauth2/callback"
          "https://*.zhyi.cc/oauth2/callback"
          "https://*.*.zhyi.cc/oauth2/callback"
        ];
      }
      {
        id = "open-webui";
        name = "Open WebUI";
        secret = {
          _secret = config.sops.secrets.dex-open-webui-secret.path;
        };
        redirectURIs = [ "https://ai.zhyi.xin/oauth/oidc/callback" ];
      }
      # keep-sorted end
    ];
  };
in
{
  imports = [ ./postgresql.nix ];

  sops.secrets = {
    glauth-bindpw = {
      sopsFile = inputs.secrets + "/common/glauth.yaml";
      mode = "0444";
    };
    dex-pocket-id-client-id = {
      sopsFile = inputs.secrets + "/common/dex.yaml";
      owner = "dex";
      group = "dex";
    };
    dex-pocket-id-client-secret = {
      sopsFile = inputs.secrets + "/common/dex.yaml";
      owner = "dex";
      group = "dex";
    };
  }
  // builtins.listToAttrs (
    builtins.map
      (
        f:
        lib.nameValuePair "dex-${f}-secret" {
          sopsFile = inputs.secrets + "/common/dex.yaml";
          owner = "dex";
          group = "dex";
        }
      )
      [
        # keep-sorted start
        "gitea"
        "grafana"
        "immich"
        "librechat"
        "netbox"
        "oauth2-proxy"
        "open-webui"
        # keep-sorted end
      ]
  );

  services.postgresql = {
    ensureDatabases = [ "dex" ];
    ensureUsers = [
      {
        name = "dex";
        ensureDBOwnership = true;
      }
    ];
  };

  systemd.services.dex = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "networking.target"
      "postgresql.service"
    ];
    script = ''
      ${utils.genJqSecretsReplacementSnippet cfg "/run/dex/config.yaml"}
      exec ${lib.getExe pkgs.dex-oidc} serve /run/dex/config.yaml
    '';
    serviceConfig = LT.serviceHarden // {
      DynamicUser = lib.mkForce false;
      User = "dex";
      Group = "dex";
      RuntimeDirectory = "dex";
      Restart = "always";
      RestartSec = "5";
    };
  };

  users.users.dex = {
    group = "dex";
    isSystemUser = true;
  };
  users.groups.dex.members = [ "nginx" ];

  lantian.nginxVhosts."login.zhyi.xin" = {
    advertiseHTTP3Port = null;

    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Dex}";
    };

    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
