{ tags, geo, ... }:
{
  index = 118;
  tags = with tags; [
    client
    lan-access
  ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 18;
  # eGPU RTX 2080 Ti（22G 改装版）；llama-swap 据此选模型量化档位。
  vramGB = 22;
  hostname = "ml-laptop.zhyi.xin";
  manualDeploy = true;
  # 2026-08-19 安装时生成并持久化到 /mnt/nix/persistent/etc/ssh。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICERfSdIV4jVRBkEfTOmdNcnzomd3g5e4s8zpqpsbevi";
  # ZeroTier node ID: 首启后 zerotier-cli info 采集回填。
  zerotier = "08d6522fba";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.55";
  };
}
