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
  ssh.ed25519Fingerprints = {
    sha1 = "0ec17eb9f8b0466d5b34a3377c3c5a3277dcc73f";
    sha256 = "367d5881f132055395b3fd9be0943029b9fd6ec3249ef96a9c4d9efc5478347c";
  };


  public.IPv4 = "101.96.199.157";

  zerotier = "ecd09d7bc2";

  ltnet.tcpTransportDomain = "volcengine.zhyi.cc";
  ltnet.tcpTransportPeers.hostdare = "hostdare.zhyi.cc";

  dn42 = {
    IPv4 = "172.20.46.229";
    region = constants.dn42.region.Asia-E;
  };
}
