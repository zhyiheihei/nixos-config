{
  LT,
  config,
  ...
}:
{
  services.rsshub = {
    enable = true;
    settings = {
      PORT = LT.port.RSSHub;
      CACHE_CONTENT_EXPIRE = "600";
    };
    redis.createLocally = true;
  };

  lantian.nginxVhosts."rsshub.${config.networking.hostName}.zhyi.cc" = {
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.RSSHub}";
      };
    };

    sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
    noIndex.enable = true;
    accessibleBy = "private";
  };
}
