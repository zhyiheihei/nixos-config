{
  config,
  ...
}:
{
  lantian.nginxVhosts."lab.${config.networking.hostName}.zhyi.cc" = {
    root = "/var/www/lab.${config.networking.hostName}.zhyi.cc";
    locations."/".enableAutoIndex = true;
    sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
    noIndex.enable = true;
    accessibleBy = "private";
  };
}
