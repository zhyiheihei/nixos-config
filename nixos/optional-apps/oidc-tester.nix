{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  oidc-tester-app = pkgs.nur-xddxdd.oidc-tester-app.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [
      ../../patches/oidc-tester-accept-plain-strings.patch
    ];
  });
in
{
  sops.secrets.dex-oidc-tester-secret.sopsFile = inputs.secrets + "/dex/oidc-tester.yaml";

  systemd.services.oidc-tester = {
    description = "OIDC Tester App";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    script = ''
      exec ${lib.getExe oidc-tester-app} \
        --host 127.0.0.1 \
        --port ${LT.portStr.OidcTester} \
        --public-url https://oidc-tester.zhyi.xin/ \
        --id oidc-tester \
        --issuer https://login.zhyi.xin \
        --secret "$(cat $CREDENTIALS_DIRECTORY/secret)"
    '';

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "3";

      User = "oidc-tester";
      Group = "oidc-tester";

      LoadCredential = [
        "secret:${config.sops.secrets.dex-oidc-tester-secret.path}"
      ];
    };
  };
  lantian.harden.oidc-tester.enable = true;

  users.users.oidc-tester = {
    group = "oidc-tester";
    isSystemUser = true;
  };
  users.groups.oidc-tester = { };

  lantian.nginxVhosts."oidc-tester.zhyi.xin" = {
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.OidcTester}";
      };
    };

    # Conflict with oidc-tester paths
    enableCommonLocationOptions = false;

    accessibleBy = "private";
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };
}
