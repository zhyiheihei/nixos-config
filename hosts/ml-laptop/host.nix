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
  # TODO: 拿到正式 SSH host key 后填入（ssh-keygen -y -f
  # /nix/persistent/etc/ssh/ssh_host_ed25519_key），并同步补上
  # ssh.ed25519Fingerprints（ssh-keygen -lf 计算 sha1/sha256）。
  # 填真实值前保持 null，避免 DNS 的 SSHFP 生成 throw 或写入错误记录。
  ssh.ed25519 = null;
  ssh.ed25519Fingerprints = {
    sha1 = null;
    sha256 = null;
  };
  # ZeroTier node ID: 首启后 zerotier-cli info 采集回填。
  zerotier = null;
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.55";
  };
}
