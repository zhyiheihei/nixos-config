{
  LT,
  lib,
  config,
  inputs,
  ...
}:
let
  wg-pubkey = import (inputs.secrets + "/wg-pubkey.nix");
  wgEndpointFor =
    name: host:
    if !(LT.this.hasTag "ipv6-only") && LT.publicIPv4For name != null then
      LT.publicIPv4For name
    else if LT.this.public.IPv6 != null && LT.publicIPv6For name != null then
      LT.publicIPv6For name
    else
      null;
  targetHosts = lib.filterAttrs (n: v: v.hasTag "server") LT.otherHosts;

  # 家宽对 10122（= WGMesh.Start + opi5p.index）的境外入站 UDP 回包丢弃：
  # greencloud 发出的 handshake response 在 router ppp0 上完全抓不到，换端口
  # 10151 后立即握手成功；rock5c/chromebox 的端口覆盖见下方配置与 exam-check-allowlist。
  # 端口按「拥有者主机」登记，两侧（监听端口与对端 Endpoint）自动一致。
  wgPortOverrides = {
    opi5p = 10151;
    rock5c = 49123;
    chromebox = 49131;
  };
  wgPortFor = n: wgPortOverrides.${n} or (LT.port.WGMesh.Start + LT.hosts.${n}.index);
in
{
  sops.secrets.wg-priv = {
    sopsFile = inputs.secrets + "/per-host/wg-priv/${config.networking.hostName}.yaml";
    group = "systemd-network";
    mode = "0660";
  };

  systemd.services.systemd-networkd.after = [ "sops-install-secrets.service" ];

  systemd.network.netdevs = lib.mapAttrs' (
    n: v:
    let
      wgEndpoint = wgEndpointFor n v;
    in
    lib.nameValuePair "wgmesh${builtins.toString v.index}" {
      netdevConfig = {
        Name = "wgmesh${builtins.toString v.index}";
        Kind = "wireguard";
      };
      wireguardConfig = {
        PrivateKeyFile = config.sops.secrets.wg-priv.path;
        ListenPort = wgPortFor n;
      };
      wireguardPeers = [
        (
          {
            AllowedIPs = [
              "0.0.0.0/0"
              "::/0"
            ];
            PublicKey = wg-pubkey."${n}";
            PersistentKeepalive = 15;
          }
          // lib.optionalAttrs (wgEndpoint != null) {
            Endpoint = "${wgEndpoint}:${builtins.toString (wgPortFor config.networking.hostName)}";
          }
        )
      ];
    }
  ) targetHosts;

  systemd.network.networks = lib.mapAttrs' (
    n: v:
    lib.nameValuePair "wgmesh${builtins.toString v.index}" {
      matchConfig = {
        Name = "wgmesh${builtins.toString v.index}";
        Kind = "wireguard";
      };

      address = [
        "fe80::${builtins.toString LT.this.index}/64"
      ]
      ++ lib.optionals (LT.this.ltnet.IPv4 != null) [ (LT.this.ltnet.IPv4 + "/32") ]
      ++ lib.optionals (LT.this.ltnet.IPv6 != null) [ (LT.this.ltnet.IPv6 + "/128") ];

      linkConfig.MTUBytes = 1400;
      networkConfig = {
        LinkLocalAddressing = "no";
      };
      routes = [
        {
          Destination = "0.0.0.0/0";
          Table = 10000 + v.index;
        }
        {
          Destination = "::/0";
          Table = 10000 + v.index;
        }
      ]
      ++ builtins.map (r: { Destination = r; }) v._routes
      ++ lib.optionals (n == LT.defaultGatewayHostName && !config.services.bird.enable) (
        # If BIRD is enabled then BGP handle these routes
        builtins.map (r: { Destination = r; }) (
          LT.defaultGatewayHostIPv4Routes ++ LT.defaultGatewayHostIPv6Routes
        )
      );
    }
  ) targetHosts;

  services.prometheus.exporters.wireguard = {
    enable = true;
    listenAddress = LT.this.ltnet.IPv4;
    port = LT.port.Prometheus.WireGuardExporter;
    latestHandshakeDelay = true;
  };

  systemd.services."prometheus-wireguard-exporter".serviceConfig = LT.serviceHarden // {
    RestartSec = "5s";
    # wg show runs over a netlink socket and needs NET_ADMIN to read dumps
    AmbientCapabilities = [ "CAP_NET_ADMIN" ];
    CapabilityBoundingSet = [ "CAP_NET_ADMIN" ];
    RestrictAddressFamilies = [
      "AF_UNIX"
      "AF_INET"
      "AF_INET6"
      "AF_NETLINK"
    ];
  };
  lantian.harden."prometheus-wireguard-exporter" = true;
}
