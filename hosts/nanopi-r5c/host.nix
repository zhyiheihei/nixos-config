{ geo, ... }:
{
  index = 118;
  system = "aarch64-linux";
  cpuThreads = 4;
  manualDeploy = true;
  hostname = "nixos-r5c.local";
  city = geo.cities."CN Ningbo";
}
