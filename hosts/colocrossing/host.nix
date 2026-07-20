{ tags, geo, ... }:
{
  index = 18;
  tags = with tags; [
    lan-access
    public-facing
    server
  ];
  cpuThreads = 4;
  hostname = "colocrossing.zhyi.cc";
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIF3dyI6XJJXk98kndydXBRFHF3SQnlkSs/B2/cDhNTUJ";

  # This VM is behind a dynamic public address. Do not publish the current
  # address as host metadata; colocrossing.zhyi.cc is maintained by DDNS.
  firewalled = true;

  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.2.52";
  };

  dn42 = {
    IPv4 = "172.20.46.225";
    region = 42;
  };

  additionalRoutes = [
    "172.20.46.224/27"
    "fdd8:1938:4e88::/48"
  ];

  zerotier = "fd2e98dccf";

  ltnet.tcpTransportPeers.jpvm = "jp.zhyi.cc";
  ltnet.tcpTransportPeers.cnvm = "cnvm.zhyi.cc";
}
