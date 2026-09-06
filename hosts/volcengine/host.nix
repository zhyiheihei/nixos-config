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
  hostname = "volcengine.zhyi.xin";
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJdPcNgpGfX6QT+clqKr4dL/FuWXxYeWVCY/lWxxA8E5 root@volcengine";

  public.IPv4 = "101.96.199.157";

  zerotier = "ecd09d7bc2";

  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
}
