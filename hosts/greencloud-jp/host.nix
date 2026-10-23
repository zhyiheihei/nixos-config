{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 130;
  tags = with tags; [
    cn-accel
    dn42
    public-facing
    server
  ];
  cpuThreads = 2;
  hostname = "45.159.48.76";
  city = geo.cities."JP Tokyo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICYtkOxbzQPS8J4d4pMfrEukWUToSnQrnJajj7m4Gcf7 root@storage";

  zerotier = "f4ec4a081c";

  public = {
    IPv4 = "45.159.48.76";
    IPv6 = "2403:71c0:2000:1253::a";
    IPv6Subnet = "2403:71c0:2000:1253::/64";
  };

  dn42 = {
    IPv4 = "172.20.46.232";
    region = constants.dn42.region.Asia-E;
  };
}
