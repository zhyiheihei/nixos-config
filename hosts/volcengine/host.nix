{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 119;
  tags = with tags; [
    public-facing
    server
  ];
  cpuThreads = 2;
  hostname = "volcengine.zhyi.cc";
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdPcNgpGfX6QT+clqKr4dL/FuWXxYeWVCY/lWxxA8E5 root@volcengine";

  public.IPv4 = "101.96.199.157";

  zerotier = "ecd09d7bc2";

  ltnet.tcpTransportDomain = "volcengine.zhyi.cc";
  ltnet.tcpTransportPeers.hostdare = "hostdare.zhyi.cc";

  dn42 = {
    IPv4 = "172.20.46.229";
    region = constants.dn42.region.Asia-E;
  };
}
