{
  LT,
  config,
  inputs,
  pkgs,
  lib,
  ...
}:
{
  sops.secrets.vaultwarden-env.sopsFile = inputs.secrets + "/vaultwarden.yaml";

  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    config = {
      SIGNUPS_ALLOWED = false;
      DOMAIN = "https://bitwarden.zhyi.xin";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = LT.port.Vaultwarden;

      USE_SENDMAIL = "true";
      SENDMAIL_COMMAND = lib.getExe pkgs.msmtp;
      SMTP_FROM = config.programs.msmtp.accounts.default.from;
      SMTP_FROM_NAME = "Vaultwarden";
    };
    environmentFile = config.sops.secrets.vaultwarden-env.path;
  };

  lantian.nginxVhosts."bitwarden.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Vaultwarden}";
      proxyWebsockets = true;
    };

    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
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
