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
  # ZeroTier 节点 ID：加入 ltnet 后由控制器按 index 113 分配 198.18.0.113
  zerotier = "447c5027d6";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.150";
  };
  dn42.region = constants.dn42.region.Asia-E;

  firewalled = true;
}
