{
  tags,
  geo,
  constants,
  ...
}:
{
  index = 124;
  system = "aarch64-linux";
  tags = with tags; [
    lan-access
    low-ram
    server
  ];
  cpuThreads = 4;
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOhJN9lnKi13oHi9Gdk9KkBiOg9p8qcp29Bm2+Jj2e5j root@lubancat1";
  zerotier = "fde3beab16";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.65";
  };
  # This server sits behind the home NAT. Match the established home server
  # topology and carry its public mesh peers over the existing WSS endpoints.
  ltnet.tcpTransportPeers.jpvm = "jpvm.zhyi.cc";
  ltnet.tcpTransportPeers.colocrossing = "colocrossing.zhyi.cc";
  ltnet.tcpTransportPeers.google = "google.zhyi.cc";
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
}
