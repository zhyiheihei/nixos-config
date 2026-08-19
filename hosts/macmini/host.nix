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
  # TODO: 拿到 Mac mini 的 SSH host key 后填入（cat ~/.ssh/ssh_host_ed25519_key.pub），
  # 并同步补上 ssh.ed25519Fingerprints（ssh-keygen -lf 计算 sha1/sha256）。
  # 在填真实值前保持 null，避免 DNS 的 SSHFP 生成 throw 或写入错误记录。
  ssh.ed25519 = null;
  ssh.ed25519Fingerprints = {
    sha1 = null;
    sha256 = null;
  };
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.54";
  };
}
