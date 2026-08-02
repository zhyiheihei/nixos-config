{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 123;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    server
  ];
  cpuThreads = 8;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOVPKMHQqr+gzsju2KvpM4GcO2G08O9AXFOxZ4UGJMJ9 root@rock5c";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.64";
  };
  # This board is behind the home NAT. Carry its public-server mesh peers over
  # the existing WSS transport, matching the established ml-home-vm topology.
  ltnet.tcpTransportPeers.jpvm = "jpvm.zhyi.cc";
  ltnet.tcpTransportPeers.colocrossing = "colocrossing.zhyi.cc";
  ltnet.tcpTransportPeers.usvm = "usvm.zhyi.cc";
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
  zerotier = "8a55fde716";
}
