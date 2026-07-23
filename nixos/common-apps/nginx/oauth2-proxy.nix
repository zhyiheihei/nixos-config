{
  lib,
  LT,
  config,
  inputs,
  ...
}:
{
  sops.secrets.oauth2-proxy-conf.sopsFile = inputs.secrets + "/common/oauth2-proxy.yaml";

  services.oauth2-proxy = {
    enable = builtins.any (v: v) (
      lib.mapAttrsToList (
        n: v: builtins.any (v: v) (lib.mapAttrsToList (n: v: v.enableOAuth) v.locations)
      ) config.lantian.nginxVhosts
    );
    clientID = "oauth-proxy";
    cookie = {
      expire = "24h";
    };
    email.domains = [ "*" ];
    httpAddress = "unix:///run/oauth2-proxy/oauth2-proxy.sock";
    keyFile = config.sops.secrets.oauth2-proxy-conf.path;
    provider = "oidc";
    setXauthrequest = true;
    extraConfig = {
      code-challenge-method = "S256";
      cookie-csrf-expire = "15m";
      # 与作者(nixos-config-exam)对齐，保留 per-request CSRF cookie。
      # 因 homepage 等页面已改为 accessibleBy=private 不再叠加 OAuth，不会
      # 因多资源路径累积 _oauth2_proxy_csrf cookie 撑爆 header buffer。
      cookie-csrf-per-request = true;
      oidc-issuer-url = "https://login.zhyi.xin";
      insecure-oidc-skip-issuer-verification = "true";
      insecure-oidc-allow-unverified-email = "true";
      scope = "openid profile email groups";
      whitelist-domain = [
        "zhyi.xin"
        "*.zhyi.xin"
        "zhyi.cc"
        "*.zhyi.cc"
      ];
    };
  };
  users.users.oauth2-proxy = {
    group = "oauth2-proxy";
    isSystemUser = true;
  };
  users.groups.oauth2-proxy.members = [ "nginx" ];

  systemd.services.oauth2-proxy = lib.mkIf config.services.oauth2-proxy.enable {
    after = [
      "network.target"
      "nginx.service"
    ];
    serviceConfig = LT.serviceHarden // {
      Restart = "always";
      RestartSec = "3";
      RuntimeDirectory = "oauth2-proxy";
      UMask = "007";
    };
  };
}
