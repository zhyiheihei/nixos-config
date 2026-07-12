{ tags, geo, ... }:
{
  index = 113;
  tags = with tags; [
    client
  ];

  # Ryzen 7 2700U 是 4 核 8 线程。
  cpuThreads = 8;

  # Colmena / deploy-rs 这类远程部署工具会优先用这里连接机器。
  # 现在先用局域网 IP；以后如果你配置了自己的 DNS，可以改成域名。
  hostname = "192.168.2.237";

  city = geo.cities."US Bellevue";

  # 这台机器是你手工安装/切换的客户端机器，不参与批量自动部署。
  manualDeploy = true;

  # SSH host public key。ssh-harden.nix 会遍历 hosts/*/host.nix，
  # 把这里的 key 自动加入系统级 known_hosts。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIVlH+ak3IpI3ThRUdUjo7/+n3Qr9+KRfx13yjQ8i3Ee";

  zerotier = "214f8619a9";

  # 家用 NAT 后面的客户端通常没有公网 IP，先不要写 public。
  # 如果以后有公网地址，再按下面格式开启：
  # public = {
  #   IPv4 = "1.2.3.4";
  #   IPv6 = "2001:db8::1";
  # };

  # 只有接入作者这套 home-lan / interconnect 网络时才开启。
  # 当前你的网段是 192.168.3.0/24，先保持注释，避免误导路由模块。
  # interconnect = {
  #   name = "home-lan";
  #   IPv4 = "192.168.3.237";
  #   IPv6 = "2001:db8::237";
  # };

  # 只有接入 DN42 后才开启。没有 DN42 地址时不要填。
  # dn42 = {
  #   IPv4 = "172.22.x.x";
  #   region = 42;
  # };
}
