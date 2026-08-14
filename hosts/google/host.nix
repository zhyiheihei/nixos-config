{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 121;
  tags = with tags; [
    public-facing
    server
    cn-accel
  ];
  cpuThreads = 2;
  hostname = "35.212.152.140";
  city = geo.cities."JP Tokyo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFdTsRnGGIr6WOBU0eG0fmaURyYUd5BIUlwBUpsmqHJT molishanguang@gmail.com";
  ssh.ed25519Fingerprints = {
    sha1 = "968f75a5809b2abe1d415636ae7a58725b08abc8";
    sha256 = "e3426724be61facf0e358a25abdf142de6ee79645381260403b96e239386c2cd";
  };
  zerotier = "47c75f186a";
  ltnet.tcpTransportDomain = "google.zhyi.cc";
  public = {
    IPv4 = "35.212.152.140";
  };
  dn42 = {
    IPv4 = "172.20.46.231";
    region = constants.dn42.region.Asia-E;
  };
}
