{ tags, geo, ... }:
{
  index = 115;
  tags = with tags; [
    lan-access
    nix-builder
    server
  ];

  # 家庭服务虚拟机，同时作为 Nix 远程构建机使用。
  # 按实际分配给 VM 的 vCPU 数调整，影响远程构建并发。
  cpuThreads = 14;

  hostname = "ml-home-vm.zhyi.cc";

  city = geo.cities."CN Ningbo";

  # 初期手动部署，避免还没验证好的构建机被批量部署误操作。
  manualDeploy = true;

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

  ltnet = {
    peers = [ "colocrossing" ];
  };

  # Keep author-style server metadata even without enabling the dn42 tag;
  # BIRD's LTNET config reads dn42.region for all server hosts.
  dn42 = {
    IPv4 = "172.22.76.115";
    region = 42;
  };
}
