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
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
  ];

  lantian.nginxVhosts."jp.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  # Standard HTTPS ingress for selected low-traffic services. Colocrossing
  # dispatches the TLS stream to the owning origin by SNI.
  services.nginx.streamConfig = ''
    resolver 1.1.1.1 8.8.8.8 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
      jp.zhyi.cc 127.0.0.1:${LT.portStr.HTTPS};
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
