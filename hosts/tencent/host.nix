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
  # First boot generates this key under /nix/persistent/etc/ssh. Add the
  # collected public key here before SOPS rekey and regular deployment.
  ssh.ed25519 = null;
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
