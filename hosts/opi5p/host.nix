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
  # 2026-08-29 NVMe 报废重装，host key 轮换（SD/NVMe 新系统首启生成）
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOXLxDaHhgehDz/DNwsilfo2mFdeNOTmcUjiHBlaY1Bz root@opi5p";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
  # 2026-08-30 NVMe 重刷清掉 /var/lib/zerotier-one，节点身份重建（旧 7e7ce20750 已废）
  zerotier = "77eccc5e34";
}
