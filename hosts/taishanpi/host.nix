{
  tags,
  geo,
  ...
}:
{
  index = 127;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    low-ram
  ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";
  zerotier = "e649a796a9";

  manualDeploy = true;
}
