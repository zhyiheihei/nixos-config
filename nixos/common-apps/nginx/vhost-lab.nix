{
  config,
  ...
}:
{
  lantian.nginxVhosts."lab.${config.networking.hostName}.xuyh0120.win" = {
    root = "/var/www/lab.${config.networking.hostName}.xuyh0120.win";
    locations."/".enableAutoIndex = true;
    sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
    noIndex.enable = true;
    accessibleBy = "private";
  };
}
