{
  inputs,
  config,
  LT,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./postgresql.nix ];

  sops.secrets.dex-tranquil-pds-secret.sopsFile = inputs.secrets + "/common/dex.yaml";
  sops.secrets.tranquil-pds-jwt-secret.sopsFile = inputs.secrets + "/tranquil-pds.yaml";
  sops.secrets.tranquil-pds-dpop-secret.sopsFile = inputs.secrets + "/tranquil-pds.yaml";
  sops.secrets.tranquil-pds-master-key.sopsFile = inputs.secrets + "/tranquil-pds.yaml";
  sops.templates.tranquil-pds-env.content = ''
    JWT_SECRET=${config.sops.placeholder.tranquil-pds-jwt-secret}
    DPOP_SECRET=${config.sops.placeholder.tranquil-pds-dpop-secret}
    MASTER_KEY=${config.sops.placeholder.tranquil-pds-master-key}
    MAIL_SMARTHOST_PASSWORD=${config.sops.placeholder.smtp-pass}
    SSO_OIDC_CLIENT_SECRET=${config.sops.placeholder.dex-tranquil-pds-secret}
  '';

  services.tranquil-pds = {
    enable = true;
    database.createLocally = true;

    environmentFiles = [ config.sops.templates.tranquil-pds-env.path ];

    settings = {
      server = {
        host = "127.0.0.1";
        port = LT.port.TranquilPDS;
        hostname = "at.zhyi.xin";
        trusted_proxy_count = 1;
      };
      database = {
        max_connections = 10;
        min_connections = 1;
      };
      email = {
        from_address = config.programs.msmtp.accounts.default.from;
        smarthost = {
          host = config.programs.msmtp.accounts.default.host;
          port = config.programs.msmtp.accounts.default.port;
          username = config.programs.msmtp.accounts.default.user;
          tls = "starttls";
        };
      };
      sso.oidc = {
        enabled = true;
        client_id = "tranquil-pds";
        issuer = "https://login.zhyi.xin";
        display_name = "Magic Flash Login";
      };
    };
  };

  # Bypass config validation that doesn't recognize secretsenvironment.etc = {
  environment.etc."tranquil-pds/config.toml".source =
    let
      settingsFormat = pkgs.formats.toml { };
    in
    lib.mkForce (settingsFormat.generate "tranquil-pds.toml" config.services.tranquil-pds.settings);

  lantian.nginxVhosts."at.zhyi.xin" = {
    serverAliases = [ "*.at.zhyi.xin" ];

    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.TranquilPDS}";
      proxyNoTimeout = true;
    };

    sslCertificate = "zerossl-at.zhyi.xin";
    noIndex.enable = true;
  };
}
