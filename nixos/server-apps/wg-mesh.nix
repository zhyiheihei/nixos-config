{
  LT,
  lib,
  config,
  inputs,
  ...
}:
let
  wg-pubkey = import (inputs.secrets + "/wg-pubkey.nix");
  targetHosts = lib.filterAttrs (n: v: v.hasTag "server") LT.otherHosts;

  wgEndpointOverrides = lib.optionalAttrs (LT.this.hasTag "lan-access") (
    lib.filterAttrs (_: v: v != null) {
      greencloud-jp = LT.publicIPv6For "greencloud-jp";
    }
  );
  wgEndpointFor =
    name: host:
    if builtins.hasAttr name wgEndpointOverrides then
      wgEndpointOverrides.${name}
    else if !(LT.this.hasTag "ipv6-only") && LT.publicIPv4For name != null then
      LT.publicIPv4For name
    else if LT.this.public.IPv6 != null && LT.publicIPv6For name != null then
      LT.publicIPv6For name
    else
      null;
  mkEndpoint =
    addr: port:
    if lib.hasInfix ":" addr then "[${addr}]:${toString port}" else "${addr}:${toString port}";
  wgPortOverrides = {
    opi5p = 10151;
    rock5c = 49123;
    chromebox = 49131;
    atk3568 = 10152;
  };
  wgPortFor = n: wgPortOverrides.${n} or (LT.port.WGMesh.Start + LT.hosts.${n}.index);
in
{
  sops.secrets.wg-priv = {
    sopsFile = inputs.secrets + "/per-host/wg-priv/${config.networking.hostName}.yaml";
    group = "systemd-network";
    mode = "0660";
  };

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
            Endpoint = mkEndpoint wgEndpoint (wgPortFor config.networking.hostName);
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

  systemd.services."prometheus-wireguard-exporter".serviceConfig = {
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
  lantian.harden."prometheus-wireguard-exporter".enable = true;
}
