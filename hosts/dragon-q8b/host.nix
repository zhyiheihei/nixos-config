{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 129;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    # 原生 aarch64 远程构建机（2026-08-29 自 opi5p 接棒；opi5p 恢复后可并存）
    nix-builder
    server
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFHX4OQA+OsOx2jxm8sqFI6a08kbC8duwP5ymzPykN5Z root@dragon-q8b";
  zerotier = "095fd45400";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.66";
  };
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
}
