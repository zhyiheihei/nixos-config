{ ... }:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  systemd.network.networks.eth0 = {
    address = [
      "140.235.38.39/24"
      "2407:cdc0:f008:12a::/64"
    ];
    gateway = [
      "140.235.38.254"
      "fe80::1"
    ];
    linkConfig.RequiredForOnline = "routable";
    matchConfig.Name = "eth0";
  };

  networking.nameservers = [
    "10.10.10.10"
    "10.10.11.11"
    "1.1.1.1"
  ];

  lantian.nginxVhosts."tw.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";
}
