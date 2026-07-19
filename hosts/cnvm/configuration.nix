{
  LT,
  lib,
  pkgs,
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

  lantian.nginxVhosts."cnvm.zhyi.cc".sslCertificate = "lets-encrypt-zhyi.cc";

  systemd.network.networks.wgmesh117.linkConfig.MTUBytes = lib.mkForce 1280;

  systemd.services.wg-mesh-wstunnel-jpvm = {
    description = "WireGuard mesh WebSocket tunnel to JPVM";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      exec ${pkgs.wstunnel}/bin/wstunnel client \
        --log-lvl WARN \
        --tls-verify-certificate \
        --http-upgrade-path-prefix ltnet-wg \
        --websocket-ping-frequency-sec 10 \
        -L 'udp://127.0.0.1:10119:127.0.0.1:10119?timeout_sec=0' \
        wss://jp.zhyi.cc:443
    '';
    serviceConfig = LT.serviceHarden // {
      DynamicUser = true;
      Restart = "always";
      RestartSec = 5;
    };
  };

  services.nginx.streamConfig = ''
    resolver 1.1.1.1 8.8.8.8 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
      cnvm.zhyi.cc 127.0.0.1:${LT.portStr.HTTPS};
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
