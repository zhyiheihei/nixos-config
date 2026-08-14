{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 114;
  tags = with tags; [
    server
    lan-access
    nix-builder
  ];

  # 强机器/虚拟机作为 Nix 远程构建机使用。
  # 按实际分配给 VM 的 vCPU 数调整，影响远程构建并发。
  cpuThreads = 28;
  # Build one derivation at a time; each build may use all cores. Keep the
  # advertised builder table and the local daemon in lockstep
  # (hosts/ml-builder/configuration.nix).
  nixBuilder.maxJobs = 1;
  nixBuilder.supportedFeatures = [
    "aarch64-cross"
    "big-parallel"
  ];

  # Colmena / deploy-rs 这类远程部署工具会优先用这里连接机器。
  hostname = "ml-builder.zhyi.cc";

  city = geo.cities."CN Ningbo";

  # SSH host public key。重装后从固定局域网地址重新读取：
  #   ssh-keyscan -p 2222 192.168.0.50 2>/dev/null | grep ssh-ed25519
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIEL+VnRYwULTdXkJtOCqoKY4COzWxHNz9glsndnSbZxl";
  ssh.ed25519Fingerprints = {
    sha1 = "cdaaa53164085c10d69a10b03bacb1f10a3e62dd";
    sha256 = "96dd6fa63e183e3cc08c9097824a204bcf258d3faa4998057da59bde91cfcb76";
  };

  zerotier = "2c86750714";
  manualDeploy = true;
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.50";
  };

  # This host is behind the home NAT. Carry its public-server mesh peers over
  # the same WSS transport used by the other home server nodes.
  ltnet.tcpTransportPeers.hostdare = "hostdare.zhyi.cc";
  ltnet.tcpTransportPeers.greencloud = "greencloud.zhyi.cc";
  ltnet.tcpTransportPeers.google = "google.zhyi.cc";
  dn42.region = constants.dn42.region.Asia-E;

}
