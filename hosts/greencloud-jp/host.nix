{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 130;
  tags = with tags; [
    dn42
    public-facing
    server
  ];
  cpuThreads = 2;
  hostname = "45.159.48.76";
  city = geo.cities."JP Tokyo";
  # Generated during the 2026-08-29 install at /nix/persistent/etc/ssh;
  # fingerprint SHA256:GJ8IBWu9Q3aPIOaYm8uc62XlJQaPagPjQ+4dyxaZGgk.
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICYtkOxbzQPS8J4d4pMfrEukWUToSnQrnJajj7m4Gcf7 root@storage";
  # ZeroTier node ID 待首次启动后用 zerotier-cli info 采集再补。

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
