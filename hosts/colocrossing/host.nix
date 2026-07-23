{ tags, geo, ... }:
{
  index = 120;
  tags = with tags; [
    dn42
    public-facing
    server
  ];
  cpuThreads = 4;
  hostname = "203.55.176.158";
  city = geo.cities."SG Singapore";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGz0eHtw3CAZuRxtgwaZhcXdZulfgNfczK8l2ZJePOvr";
  zerotier = "76d1b20a73";
  ltnet.tcpTransportDomain = "colocrossing.zhyi.cc";
  public = {
    IPv4 = "203.55.176.158";
    IPv6 = "2a11:8083:11:191b::a";
    IPv6Subnet = "2a11:8083:11:191b::/64";
  };

  dn42 = {
    IPv4 = "172.20.46.230";
    region = 52;
  };

  additionalRoutes = [
    "172.20.46.224/27"
    "fdd8:1938:4e88::/48"
  ];
}
