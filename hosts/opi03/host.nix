{ tags, geo, ... }:
{
  index = 126;
  system = "aarch64-linux";
  tags = with tags; [ lan-access ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";

  manualDeploy = true;
}
