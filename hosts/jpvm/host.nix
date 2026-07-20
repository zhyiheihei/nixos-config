{ tags, geo, ... }:
{
  index = 117;
  tags = with tags; [
    dn42
    low-disk
    low-ram
    public-facing
    server
  ];
  cpuThreads = 1;
  hostname = "36.50.85.113";
  city = geo.cities."JP Tokyo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEBFLiDovNcpzs3OhpkCoc/ByL6DoTdz1H8LlZojX1Pn";
  zerotier = "a073934677";
  ltnet.tcpTransportDomain = "jp.zhyi.cc";
  public = {
    IPv4 = "36.50.85.113";
  };
  dn42 = {
    IPv4 = "172.20.46.227";
    region = 52;
  };
}
