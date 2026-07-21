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

  lantian.nginxVhosts."sg.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # Standard HTTPS ingress for selected low-traffic services. Colocrossing
  # dispatches the TLS stream to the owning origin by SNI.
  services.nginx.streamConfig = ''
    resolver 1.1.1.1 8.8.8.8 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
      sg.zhyi.cc 127.0.0.1:${LT.portStr.HTTPS};
      uni-api.sgvm.zhyi.cc 127.0.0.1:${LT.portStr.HTTPS};
      default ${LT.hosts.colocrossing.ltnet.IPv4}:443;
    }

    server {
      listen 0.0.0.0:443;
      listen [::]:443;
      ssl_preread on;
      proxy_connect_timeout 10s;
      proxy_timeout 3600s;
      proxy_pass $https_origin;
    }
  '';

}
