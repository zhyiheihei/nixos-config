{ tags, geo, ... }:
{
  index = 118;
  tags = with tags; [
    lan-access
    server
  ];

  cpuThreads = 4;
  hostname = "logvm.zhyi.cc";
  city = geo.cities."CN Ningbo";
  ssh.ed25519 = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJJm1gZb51/N/fVV1LV+dCs6l9EHbXeTUj42puGIwrX6";

  firewalled = true;

  interconnect = {
    name = "home-lan";
    IPv4 = "192.168.2.55";
  };

  zerotier = "cba3cdffbf";

  ltnet.tcpTransportPeers.jpvm = "jp.zhyi.cc";

  dn42 = {
    IPv4 = "172.20.46.228";
    region = 42;
  };
}
