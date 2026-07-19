{ tags, geo, ... }:
{
  index = 114;
  tags = with tags; [
    lan-access
    nix-builder
  ];

  # 强机器/虚拟机作为 Nix 远程构建机使用。
  # 按实际分配给 VM 的 vCPU 数调整，影响远程构建并发。
  cpuThreads = 28;

  # Colmena / deploy-rs 这类远程部署工具会优先用这里连接机器。
  hostname = "ml-builder.zhyi.cc";

  city = geo.cities."CN Ningbo";

  # SSH host public key。重装后从固定局域网地址重新读取：
  #   ssh-keyscan -p 2222 192.168.2.50 2>/dev/null | grep ssh-ed25519
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEL+VnRYwULTdXkJtOCqoKY4COzWxHNz9glsndnSbZxl";

  zerotier = "2c86750714";

  # 家用 NAT 后面的客户端通常没有公网 IP，先不要写 public。
  # 如果以后有公网地址，再按下面格式开启：
  # public = {
  #   IPv4 = "1.2.3.4";
  #   IPv6 = "2001:db8::1";
  # };

  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.2.50";
  };

  # 只有接入 DN42 后才开启。没有 DN42 地址时不要填。
  # dn42 = {
  #   IPv4 = "172.22.x.x";
  #   region = 42;
  # };
}
