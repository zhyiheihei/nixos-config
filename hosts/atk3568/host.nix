{
  tags,
  geo,
  ...
}:
{
  index = 133;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
  ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.63";
  };
}
