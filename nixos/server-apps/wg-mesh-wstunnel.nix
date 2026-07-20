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
              -L 'udp://127.0.0.1:${localPort}:127.0.0.1:${localPort}?timeout_sec=0' \
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
