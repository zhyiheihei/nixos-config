{
  config,
  lib,
  pkgs,
  LT,
  ...
}:
let
  cfg = LT.this.ltnet;
  localPort = builtins.toString (LT.port.WGMesh.Start + LT.this.index);
  # 每个对端的 wstunnel client 需要不同的本地 UDP 监听端口，避免多 peer 时端口冲突。
  # 服务端通过 --restrict-to 限制转发目标端口为 WGMesh.Start + 客户端 index，
  # 因此 -L 的第二个端口（远程目标）必须保持 localPort，第一个端口（本地监听）可改。
  clientPort = peer: builtins.toString (LT.port.WGMesh.Start + 256 + LT.hosts.${peer}.index);
  tunnelClients = lib.filterAttrs (
    _: host: builtins.hasAttr config.networking.hostName host.ltnet.tcpTransportPeers
  ) LT.otherHosts;
  serverTargets = lib.concatStringsSep " " (
    lib.mapAttrsToList (
      _: host: "--restrict-to 127.0.0.1:${builtins.toString (LT.port.WGMesh.Start + host.index)}"
    ) tunnelClients
  );
in
{
  config = lib.mkMerge [
    (lib.mkIf (cfg.tcpTransportPeers != { }) {
      systemd.services = lib.mapAttrs' (
        peer: endpoint:
        lib.nameValuePair "wg-mesh-wstunnel-${peer}" {
          description = "WireGuard mesh WSS transport to ${peer}";
          after = [ "network-online.target" ];
          wants = [ "network-online.target" ];
          wantedBy = [ "multi-user.target" ];
          script = ''
            exec ${pkgs.wstunnel}/bin/wstunnel client \
              --log-lvl WARN \
              --tls-verify-certificate \
              --http-upgrade-path-prefix ltnet-wg \
              --websocket-ping-frequency-sec 10 \
              -L 'udp://127.0.0.1:${clientPort peer}:127.0.0.1:${localPort}?timeout_sec=0' \
              wss://${endpoint}
          '';
          serviceConfig = LT.serviceHarden // {
            DynamicUser = true;
            Restart = "always";
            RestartSec = 5;
          };
        }
      ) cfg.tcpTransportPeers;
    })

    (lib.mkIf (cfg.tcpTransportDomain != null) {
      lantian.nginxVhosts.${cfg.tcpTransportDomain}.locations."/ltnet-wg/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.WGMesh.WebSocket}";
        proxyWebsockets = true;
        proxyNoTimeout = true;
      };

      systemd.services.wg-mesh-wstunnel-server = {
        description = "WireGuard mesh WSS transport server";
        after = [ "network.target" ];
        wantedBy = [ "multi-user.target" ];
        script = ''
          exec ${pkgs.wstunnel}/bin/wstunnel server \
            --log-lvl WARN \
            ${serverTargets} \
            ws://127.0.0.1:${LT.portStr.WGMesh.WebSocket}
        '';
        serviceConfig = LT.serviceHarden // {
          DynamicUser = true;
          Restart = "always";
          RestartSec = 5;
        };
      };
    })
  ];
}
