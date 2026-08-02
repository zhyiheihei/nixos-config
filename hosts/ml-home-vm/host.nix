{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 115;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    server
  ];

  # The logical home-service identity is hosted by ROCK 5C after migration.
  cpuThreads = 8;

  city = geo.cities."CN Ningbo";

  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOVPKMHQqr+gzsju2KvpM4GcO2G08O9AXFOxZ4UGJMJ9 root@rock5c";

  zerotier = "8a55fde716";

  firewalled = true;

  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.51";
  };

  ltnet.tcpTransportPeers.jpvm = "jpvm.zhyi.cc";
  ltnet.tcpTransportPeers.colocrossing = "colocrossing.zhyi.cc";
  ltnet.tcpTransportPeers.usvm = "usvm.zhyi.cc";

  # Keep author-style server metadata even without enabling the dn42 tag;
  # BIRD's LTNET config reads dn42.region for all server hosts.
  dn42 = {
    IPv4 = "172.20.46.226";
    region = constants.dn42.region.Asia-E;
  };
}
