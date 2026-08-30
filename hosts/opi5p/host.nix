{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 122;
  system = "aarch64-linux";
  # Native ARM fallback builder: this RK3588 handles aarch64 derivations
  # whose build scripts must execute target code; the dedicated build path
  # remains ml-builder (see docs/agent/hosts-overview.md).
  # nix-builder tag 暂摘（2026-08-29 机器故障，构建职责由 dragon-q8b 接棒），
  # 机器恢复后加回。
  tags = with tags; [
    lan-access
    server
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";
  # 2026-08-30 从 8-27 快照恢复 etc/ssh，钥匙回到原生 mloC
  #（SHA256:mloCmodzu1MrdnZUxwRfRoMQWORF9xKgS1UccjwIrBw）；secrets 已全库
  # rekey 到该钥匙的 age 形式（secrets 仓 372bf21）。8-29 的 H7+p 私钥
  # 随 dragon 无持久化 /root 蒸发，已废止。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIITTMAnkcLtBaK31sz6e7aGEvSkqKZuEeeJETBmK33Ef root@opi5p";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
  zerotier = "7e7ce20750";
}
