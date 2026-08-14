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
  ssh.ed25519Fingerprints = {
    sha1 = "2925a0b52bace1d663b3c85ec553a5009b14bcde";
    sha256 = "2e6894fbd6252a81fb269b1a31afc74fd0e68ad72591ef09618af64e0968c8d2";
  };
  zerotier = "fde3beab16";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.65";
  };
  # This server sits behind the home NAT. Match the established home server
  # topology and carry its public mesh peers over the existing WSS endpoints.
  ltnet.tcpTransportPeers.hostdare = "hostdare.zhyi.cc";
  ltnet.tcpTransportPeers.greencloud = "greencloud.zhyi.cc";
  ltnet.tcpTransportPeers.google = "google.zhyi.cc";
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
}
