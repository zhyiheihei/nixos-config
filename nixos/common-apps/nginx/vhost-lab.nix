{
  config,
  ...
}:
{
  lantian.localVhosts.lab = {
    root = "/var/www/lab.${config.networking.hostName}.zhyi.xin";
    locations."/".enableAutoIndex = true;
  };
}
