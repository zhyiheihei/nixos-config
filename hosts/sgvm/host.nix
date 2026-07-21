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
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDddPMm5H+q5o7EY2ER3aFoRXEgv3TouTSIMQyNYF/Dg";
  ltnet.tcpTransportDomain = "sg.zhyi.cc";
  public = {
    IPv4 = "203.55.176.158";
    IPv6 = "2a11:8083:11:191b::a";
    IPv6Subnet = "2a11:8083:11:191b::/64";
  };
  dn42 = {
    IPv4 = "172.20.46.230";
    region = 52;
  };
}
