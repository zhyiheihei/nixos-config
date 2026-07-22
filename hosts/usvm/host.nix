{ tags, geo, ... }:
{
  index = 117;
  tags = with tags; [
    low-disk
    low-ram
    public-facing
    server
  ];
  cpuThreads = 2;
  hostname = "35.212.152.140";
  city = geo.cities."JP Tokyo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIYKVNgghOCp0JSDff/CtsY1H17eTjjkp/X82m2bPG/e";
  ltnet.tcpTransportDomain = "usvm.zhyi.cc";
  public = {
    IPv4 = "35.212.152.140";
  };
  dn42 = {
    IPv4 = "172.20.46.227";
    region = 52;
  };
}
