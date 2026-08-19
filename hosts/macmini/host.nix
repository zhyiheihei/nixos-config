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
  hostname = "macmini.zhyi.cc";
  manualDeploy = true;
  # Mac mini 的 macOS 自带 OpenSSH host key（/etc/ssh/ssh_host_ed25519_key）。
  # 指纹由 ssh-keygen -lf 计算：sha1/sha256 为去掉前缀的 hex。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII+JNpF7l1s6JW1tymfKseBd9ILFVqxkmw1wYOrKmguZ";
  ssh.ed25519Fingerprints = {
    sha1 = "d740d87c6b6e51da5f86155c390a65c7620515a8";
    sha256 = "80436f5934802bd4b22c9c4d679f4add2296c7b3d05e80ef02135c9dc041cacf";
  };
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.54";
  };
}
