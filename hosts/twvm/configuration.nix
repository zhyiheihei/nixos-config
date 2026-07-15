{
  LT,
  ...
}:
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

  # Standard HTTPS ingress for selected low-traffic services. Colocrossing
  # dispatches the TLS stream to the owning origin by SNI.
  services.nginx.streamConfig = ''
    resolver 1.1.1.1 8.8.8.8 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
      tw.zhyi.cc 127.0.0.1:${LT.portStr.HTTPS};
      sub.zhyi.cc ${LT.hosts.ml-home-vm.ltnet.IPv4}:${LT.portStr.HTTPS};
      default home-ddns.zhyi.cc:8443;
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
