{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 128;
  tags = with tags; [
    dn42
    public-facing
    server
    cn-accel
  ];
  cpuThreads = 2;
  hostname = "tencent.zhyi.cc";
  city = geo.cities."KR Seoul";
  manualDeploy = true;
  # Generated during the 2026-08-13 reinstall at /nix/persistent/etc/ssh;
  # fingerprint SHA256:mQsADD14m6vckwHEmIan3gOcixlPtRos7eaNQQNiCEo.
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMKKFpoUJp+JQE4eKn47qIpeBo9y7eclUqoO0zaUIVY8 root@localhost";
  zerotier = null;

  ltnet.tcpTransportDomain = "tencent.zhyi.cc";

  public = {
    IPv4 = "43.155.239.124";
  };

  dn42 = {
    IPv4 = "172.20.46.228";
    region = constants.dn42.region.Asia-E;
  };
}
