{
  inputs,
  LT,
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

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

  lantian.nginxVhosts."jp.zhyi.cc" = {
    locations."/ltnet-wg/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.WGMesh.WebSocket}";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
  };

  systemd.services.wg-mesh-wstunnel-server = {
    description = "WireGuard mesh WebSocket tunnel server";
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];
    script = ''
      exec ${pkgs.wstunnel}/bin/wstunnel server \
        --log-lvl WARN \
        --restrict-to 127.0.0.1:10018 \
        --restrict-to 127.0.0.1:10119 \
        ws://127.0.0.1:${LT.portStr.WGMesh.WebSocket}
    '';
    serviceConfig = LT.serviceHarden // {
      DynamicUser = true;
      Restart = "always";
      RestartSec = 5;
    };
  };

  systemd.network.networks.wgmesh18.linkConfig.MTUBytes = lib.mkForce 1280;
  systemd.network.networks.wgmesh119.linkConfig.MTUBytes = lib.mkForce 1280;

  # Standard HTTPS ingress for selected low-traffic services. Colocrossing
  # dispatches the TLS stream to the owning origin by SNI.
  services.nginx.streamConfig = ''
    resolver 1.1.1.1 8.8.8.8 valid=60s ipv6=off;

    map $ssl_preread_server_name $https_origin {
      jp.zhyi.cc 127.0.0.1:${LT.portStr.HTTPS};
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

    server {
      listen 0.0.0.0:443 udp reuseport;
      listen [::]:443 udp reuseport;
      proxy_timeout 3600s;
      proxy_pass ${LT.hosts.colocrossing.ltnet.IPv4}:${LT.portStr.HTTPS};
    }
  '';

}
