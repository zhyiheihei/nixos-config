{
  inputs,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    ../../nixos/optional-apps/axonhub.nix
    ../../nixos/optional-apps/grafana.nix
    ../../nixos/optional-apps/metapi.nix
    ../../nixos/optional-apps/n8n
    ../../nixos/optional-apps/open-webui
    ../../nixos/optional-apps/prometheus
  ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    address = [
      "203.55.176.158/25"
      "2a11:8083:11:191b::a/64"
    ];
    routes = [
      {
        routeConfig = {
          Destination = "0.0.0.0/0";
          Gateway = "203.55.176.254";
        };
      }
      {
        routeConfig = {
          Destination = "::/0";
          Gateway = "2a11:8083:11::1";
          GatewayOnLink = true;
        };
      }
    ];
    networkConfig.IPv6AcceptRA = "no";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
    "2001:4860:4860::8888"
    "2001:4860:4860::8844"
  ];

  lantian.nginxVhosts."sgvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

}
