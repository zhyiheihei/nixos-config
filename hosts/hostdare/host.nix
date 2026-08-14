{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 117;
  tags = with tags; [
    dn42
    public-facing
    server
    cn-accel
  ];
  cpuThreads = 1;
  hostname = "36.50.85.113";
  city = geo.cities."JP Tokyo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEBFLiDovNcpzs3OhpkCoc/ByL6DoTdz1H8LlZojX1Pn";
  ssh.ed25519Fingerprints = {
    sha1 = "a05136f2308ba8bf19b06fe70a7168e910032552";
    sha256 = "1db641b0a11305758f0ebad9902b37f43efa803a22d87b4d3de5546f852d09d4";
  };
  zerotier = "a073934677";
  ltnet.tcpTransportDomain = "hostdare.zhyi.cc";
  public = {
    IPv4 = "36.50.85.113";
  };
  dn42 = {
    IPv4 = "172.20.46.227";
    region = constants.dn42.region.Asia-E;
  };
}
