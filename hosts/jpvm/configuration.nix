{
  inputs,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/uni-api.nix

    "${inputs.secrets}/nixos-hidden-module/aacd9f37de95f98d"
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
  ];

  lantian.nginxVhosts."jpvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

}
