{ tags, geo, ... }:
{
  index = 115;
  tags = with tags; [
    lan-access
    nix-builder
    server
  ];

  # 强机器/虚拟机作为 Nix 远程构建机使用。
  # 按实际分配给 VM 的 vCPU 数调整，影响远程构建并发。
  cpuThreads = 14;

  # Colmena / deploy-rs 这类远程部署工具会优先用这里连接机器。
  # 这里先用当前测试 VM 的局域网地址；如果 VM IP 不同，改这里。
  hostname = "192.168.2.135";

  city = geo.cities."US Bellevue";

  # 初期手动部署，避免还没验证好的构建机被批量部署误操作。
  manualDeploy = true;

  # SSH host public key。拿到 ml-builder 的 host key 后取消注释：
  #   ssh-keyscan -p 2222 192.168.2.135 2>/dev/null | grep ssh-ed25519
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
    IPv4 = "192.168.2.135";
  };

  # Keep author-style server metadata even without enabling the dn42 tag;
  # BIRD's LTNET config reads dn42.region for all server hosts.
  dn42 = {
    IPv4 = "172.22.76.115";
    region = 42;
  };
}
