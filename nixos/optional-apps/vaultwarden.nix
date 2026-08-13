{
  config,
  LT,
  ...
}:
{
  # The dex-vaultwarden-secret itself is declared in dex.nix (mode 0444 so
  # both the dex and vaultwarden service users can read it); here we only
  # render it into a systemd EnvironmentFile for the vaultwarden unit.
  sops.templates."vaultwarden-sso.env" = {
    content = "SSO_CLIENT_SECRET=${config.sops.secrets.dex-vaultwarden-secret.path}";
    owner = "vaultwarden";
    group = "vaultwarden";
  };

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    environmentFile = [ config.sops.templates."vaultwarden-sso.env".path ];
    config = {
      SIGNUPS_ALLOWED = false;
      DOMAIN = "https://bitwarden.zhyi.xin";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = LT.port.Vaultwarden;

      # SSO (OIDC) login via Dex (login.zhyi.xin), same chain as the other
      # fleet services (Pocket ID -> Dex). Optional: users can still log in
      # with email + master password; SSO only replaces the authentication
      # step, unlocking the vault still requires the master password.
      SSO_ENABLED = true;
      SSO_AUTHORITY = "https://login.zhyi.xin";
      SSO_CLIENT_ID = "vaultwarden";
      SSO_PKCE = true;
      SSO_SIGNUPS_MATCH_EMAIL = true;
      # Refuse accounts when the IdP cannot confirm the email is verified
      SSO_ALLOW_UNKNOWN_EMAIL_VERIFICATION = false;
    };
  };

  lantian.nginxVhosts = {
    "bitwarden.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Vaultwarden}";
        proxyWebsockets = true;
      };

      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
    "bitwarden.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.Vaultwarden}";
        proxyWebsockets = true;
      };

      accessibleBy = "localhost";
      noIndex.enable = true;
    };
  };

  systemd.services.vaultwarden = {
    serviceConfig = {
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_LOCAL"
        "AF_NETLINK"
      ];
    };
  };
}
