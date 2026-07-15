{ tags, geo, ... }:
{
  index = 116;
  tags = with tags; [ ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 16;
  hostname = "pve-5700u.zhyi.cc";
  manualDeploy = true;
}
