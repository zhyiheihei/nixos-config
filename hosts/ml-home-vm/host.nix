{ tags, geo, ... }:
{
  index = 115;
  tags = with tags; [
    lan-access
    server
  ];

  # 家庭服务虚拟机，不参与 Hydra 远程构建。
  cpuThreads = 14;

  city = geo.cities."CN Ningbo";

  # 当前虚拟机的 SSH host public key。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDax7ee1Yjl1Ei1PqF5ef8QpThqI7YqTMDN5obfqL5+4";

  zerotier = "c340ae9a91";

  firewalled = true;

  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.51";
  };

  ltnet.tcpTransportPeers.jpvm = "jpvm.zhyi.cc";
  ltnet.tcpTransportPeers.cnvm = "cnvm.zhyi.cc";
  ltnet.tcpTransportPeers.colocrossing = "colocrossing.zhyi.cc";
  ltnet.tcpTransportPeers.usvm = "usvm.zhyi.cc";

  # Keep author-style server metadata even without enabling the dn42 tag;
  # BIRD's LTNET config reads dn42.region for all server hosts.
  dn42 = {
    IPv4 = "172.20.46.226";
    region = 42;
  };
}
