{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 120;
  tags = with tags; [
    dn42
    public-facing
    server
    cn-accel
  ];
  cpuThreads = 4;
  hostname = "203.55.176.158";
  city = geo.cities."SG Singapore";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIGz0eHtw3CAZuRxtgwaZhcXdZulfgNfczK8l2ZJePOvr";
  ssh.ed25519Fingerprints = {
    sha1 = "abcb08a425fc44e98de7e0f8694ed6afe073bc78";
    sha256 = "3bb68eabc883ed1c5faeb61e9f43d2fa892af8b7503ca912c1b85fc653fe6606";
  };
  zerotier = "76d1b20a73";
  ltnet.tcpTransportDomain = "colocrossing.zhyi.cc";
  public = {
    IPv4 = "203.55.176.158";
    IPv6 = "2a11:8083:11:191b::a";
    IPv6Subnet = "2a11:8083:11:191b::/64";
  };

  dn42 = {
    IPv4 = "172.20.46.230";
    region = constants.dn42.region.Asia-SE;
  };

  additionalRoutes = [
    "172.20.46.224/27"
    "fdd8:1938:4e88::/48"
  ];
}
