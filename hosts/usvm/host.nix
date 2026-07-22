{ tags, geo, ... }:
{
  index = 121;
  tags = with tags; [
    low-disk
    low-ram
    public-facing
    server
  ];
  cpuThreads = 2;
  hostname = "35.212.152.140";
  city = geo.cities."JP Tokyo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdTsRnGGIr6WOBU0eG0fmaURyYUd5BIUlwBUpsmqHJT molishanguang@gmail.com";
  zerotier = "47c75f186a";
  ltnet.tcpTransportDomain = "usvm.zhyi.cc";
  public = {
    IPv4 = "35.212.152.140";
  };
  dn42 = {
    IPv4 = "172.20.46.231";
    region = 52;
  };
}
