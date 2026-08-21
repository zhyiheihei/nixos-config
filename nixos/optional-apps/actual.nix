{
  LT,
  inputs,
  config,
  ...
}:
{
  sops.secrets.dex-actual-secret.sopsFile = inputs.secrets + "/common/dex.yaml";
  sops.templates.actual-env.content = ''
    ACTUAL_OPENID_CLIENT_SECRET=${config.sops.placeholder.dex-actual-secret}
  '';

  services.actual = {
    enable = true;
    settings = {
      hostname = "127.0.0.1";
      port = LT.port.Actual;
    };
  };

  systemd.services.actual = {
    environment = {
      ACTUAL_OPENID_AUTHORIZATION_ENDPOINT = "https://login.zhyi.xin/auth";
      ACTUAL_OPENID_TOKEN_ENDPOINT = "https://login.zhyi.xin/token";
      ACTUAL_OPENID_USERINFO_ENDPOINT = "https://login.zhyi.xin/userinfo";
      ACTUAL_OPENID_CLIENT_ID = "actual";
      ACTUAL_OPENID_SERVER_HOSTNAME = "https://actual.zhyi.xin";
      ACTUAL_OPENID_AUTH_METHOD = "oauth2";
      ACTUAL_OPENID_ENFORCE = "true";
      ACTUAL_TOKEN_EXPIRATION = "openid-provider";
      ACTUAL_USER_CREATION_MODE = "login";
    };
    serviceConfig = {
      EnvironmentFile = config.sops.templates.actual-env.path;
    };
  };

  lantian.nginxVhosts."actual.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Actual}";
      # Budget sync/upload can be large and long-running.
      # COOP/COEP headers required for SharedArrayBuffer are set by the app
      # itself and passed through untouched.
      proxyNoTimeout = true;
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };
}
