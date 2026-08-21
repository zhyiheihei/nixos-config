{ tags, geo, ... }:
{
  index = 115;
  system = "aarch64-darwin";
  tags = with tags; [
    macos
    lan-access
  ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 8;
  hostname = "macmini.zhyi.xin";
  manualDeploy = true;
  # Mac mini 的 macOS 自带 OpenSSH host key（/etc/ssh/ssh_host_ed25519_key）。
  # 指纹由 ssh-keygen -lf 计算：sha1/sha256 为去掉前缀的 hex。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+JNpF7l1s6JW1tymfKseBd9ILFVqxkmw1wYOrKmguZ";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.54";
  };
}
