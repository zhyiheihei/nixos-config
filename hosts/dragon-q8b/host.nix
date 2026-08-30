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
    # 2026-08-31 aarch64 构建机切回 opi5p：dragon 8G 内存天花板，
    # HA 构建期间 OOM 连环杀 rslsync/postgres/nix-daemon 实证。
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
