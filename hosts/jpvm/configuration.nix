{
  inputs,
  LT,
  lib,
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

  lantian.nginxVhosts = lib.genAttrs [
    "flapalerted.zhyi.cc"
    "netbox.zhyi.cc"
  ] (hostname: {
    locations."/" = {
      proxyPass = "https://${LT.hosts.colocrossing.ltnet.IPv4}:${LT.portStr.HTTPS}";
      proxyWebsockets = true;
      extraConfig = ''
        proxy_ssl_name ${hostname};
        proxy_ssl_server_name on;
      '';
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  });

}
