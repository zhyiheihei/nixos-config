{
  LT,
  lib,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix
  ];

  boot.kernelParams = [ "console=ttyS0,115200" ];

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    networkConfig.DHCP = "ipv4";
  };

  networking.nameservers = [
    "8.8.8.8"
    "8.8.4.4"
    "1.1.1.1"
  ];

  # CNVM only passes TLS at layer four. It must not inherit the shared HTTP
  # vhosts, which require the synchronized ACME certificate tree.
  services.nginx.virtualHosts = lib.mkForce { };

  services.nginx.streamConfig = ''
    resolver 1.1.1.1 8.8.8.8 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
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

    # The upstream layout serves HTTP/3 on UDP 443 directly. This host keeps
    # that public interface while the home origin listens on UDP 8443.
    server {
      listen 0.0.0.0:443 udp reuseport;
      listen [::]:443 udp reuseport;
      proxy_timeout 3600s;
      proxy_pass ${LT.hosts.colocrossing.ltnet.IPv4}:${LT.portStr.HTTPS};
    }
  '';
}
