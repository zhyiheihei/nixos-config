{ tags, geo, ... }:
{
  index = 112;
  tags = with tags; [ ];
  hostname = "192.168.0.1";
  cpuThreads = 2;
  manualDeploy = true;
  city = geo.cities."CN Ningbo";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.1";
  };
}
