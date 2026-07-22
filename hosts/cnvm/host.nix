{ tags, geo, ... }:
{
  index = 119;
  tags = with tags; [
    low-disk
    low-ram
    server
  ];
  cpuThreads = 2;
  hostname = "cnvm.zhyi.cc";
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdPcNgpGfX6QT+clqKr4dL/FuWXxYeWVCY/lWxxA8E5 root@cnvm";

  public.IPv4 = "101.96.199.157";

  zerotier = "ecd09d7bc2";

  ltnet.tcpTransportDomain = "cnvm.zhyi.cc";
  ltnet.tcpTransportPeers.jpvm = "jpvm.zhyi.cc";

  dn42 = {
    IPv4 = "172.20.46.229";
    region = 42;
  };
}
