{
  config,
  ...
}:
{
  lantian.localVhosts.lab = {
    root = "/var/www/lab.${config.networking.hostName}.zhyi.xin";
    locations."/".enableAutoIndex = true;
  };

  systemd.tmpfiles.settings.nginx = {
    "/var/www/lab.${config.networking.hostName}.zhyi.xin"."d" = {
      mode = "755";
      user = "root";
      group = "root";
    };
  };
}
