{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 113;
  system = "aarch64-linux";

  tags = with tags; [
    server
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEQaHoHOJevao9T+GsKWajKnvJYA2pAw2HiyuCeadZ6H root@venus";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.150";
  };
  dn42.region = constants.dn42.region.Asia-E;

  firewalled = true;
}
