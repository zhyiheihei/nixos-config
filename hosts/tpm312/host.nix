{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 135;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    low-ram
    server
  ];
  cpuThreads = 6;
  city = geo.cities."CN Ningbo";
  manualDeploy = true;
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.67";
  };

  dn42.region = constants.dn42.region.Asia-E;
}
