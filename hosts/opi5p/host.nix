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
  # remains ml-builder (see docs/reference/hosts-overview.md).
  tags = with tags; [
    lan-access
    nix-builder
    server
  ];
  cpuThreads = 8;
  # This node also runs databases, media services and reDroid. Keep native ARM
  # builds available, but reserve most CPU and memory for production services.
  # In particular, do not advertise big-parallel: kernels and similarly heavy
  # jobs belong on the dedicated builder path.
  nixBuilder.maxJobs = 1;
  nixBuilder.supportedFeatures = [ ];
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIITTMAnkcLtBaK31sz6e7aGEvSkqKZuEeeJETBmK33Ef root@opi5p";
  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.0.62";
  };
  # This board is behind the home NAT. Carry its public-server mesh peers over
  # the existing WSS transport, matching the established ml-home-vm topology.
  ltnet.tcpTransportPeers.hostdare = "hostdare.zhyi.cc";
  ltnet.tcpTransportPeers.greencloud = "greencloud.zhyi.cc";
  ltnet.tcpTransportPeers.google = "google.zhyi.cc";
  # Server-role BIRD configuration consumes the region even without dn42.
  dn42.region = constants.dn42.region.Asia-E;
  zerotier = "7e7ce20750";
}
