{ tags, geo, ... }:
{
  index = 115;
  tags = with tags; [
    lan-access
    server
  ];

  # 家庭服务虚拟机，不参与 Hydra 远程构建。
  cpuThreads = 14;

  hostname = "ml-home-vm.zhyi.cc";

  city = geo.cities."CN Ningbo";

  # 当前虚拟机的 SSH host public key。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIDax7ee1Yjl1Ei1PqF5ef8QpThqI7YqTMDN5obfqL5+4";

  zerotier = "c340ae9a91";

  # 家用 NAT 后面的客户端通常没有公网 IP，先不要写 public。
  # 如果以后有公网地址，再按下面格式开启：
  # public = {
  #   IPv4 = "1.2.3.4";
  #   IPv6 = "2001:db8::1";
  # };

  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.2.51";
  };

  ltnet.tcpTransportPeers.jpvm = "jpvm.zhyi.cc";
  ltnet.tcpTransportPeers.cnvm = "cnvm.zhyi.cc";
  ltnet.tcpTransportPeers.sgvm = "sgvm.zhyi.cc";

  # Keep author-style server metadata even without enabling the dn42 tag;
  # BIRD's LTNET config reads dn42.region for all server hosts.
  dn42 = {
    IPv4 = "172.20.46.226";
    region = 42;
  };
}
