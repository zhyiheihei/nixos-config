{
  LT,
  ...
}:
{
  services.vaultwarden = {
    enable = true;
    dbBackend = "sqlite";
    config = {
      SIGNUPS_ALLOWED = false;
      DOMAIN = "https://bitwarden.zhyi.xin";
      ROCKET_ADDRESS = "127.0.0.1";
      ROCKET_PORT = LT.port.Vaultwarden;
    };
  };

  lantian.nginxVhosts."bitwarden.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.Vaultwarden}";
      proxyWebsockets = true;
    };

    sslCertificate = "lets-encrypt-zhyi.xin";
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
