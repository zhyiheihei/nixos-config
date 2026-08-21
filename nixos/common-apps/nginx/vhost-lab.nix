{
  config,
  ...
}:
{
  lantian.nginxVhosts."lab.${config.networking.hostName}.zhyi.xin" = {
    root = "/var/www/lab.${config.networking.hostName}.zhyi.xin";
    locations."/".enableAutoIndex = true;
    sslCertificate = "zerossl-${config.networking.hostName}.zhyi.xin";
    noIndex.enable = true;
    accessibleBy = "private";
  };
}
