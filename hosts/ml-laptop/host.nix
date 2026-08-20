{ tags, geo, ... }:
{
  index = 118;
  tags = with tags; [
    client
    lan-access
  ];
  city = geo.cities."CN Ningbo";
  cpuThreads = 18;
  hostname = "ml-laptop.zhyi.cc";
  manualDeploy = true;
  # 2026-08-19 安装时生成并持久化到 /mnt/nix/persistent/etc/ssh。
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICERfSdIV4jVRBkEfTOmdNcnzomd3g5e4s8zpqpsbevi";
  ssh.ed25519Fingerprints = {
    sha1 = "UT9uDX/udYPQDhI3xO2ujdaUQXA";
    sha256 = "b/ZWXPQaBbxiZZ65mHc12a6qEahg/JvQN8D2EeMJ/uY";
  };
  # ZeroTier node ID: 首启后 zerotier-cli info 采集回填。
  zerotier = "08d6522fba";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.55";
  };
}
