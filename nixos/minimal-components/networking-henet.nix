{
  config,
  lib,
  LT,
  ...
}:
let
  cfg = config.networking.henet;
in
{
  options.networking.henet = {
    enable = lib.mkEnableOption "HE.net IPv6 tunnel";

    remote = lib.mkOption {
      type = lib.types.str;
      description = "Remote tunnel endpoint IP address";
    };

    addresses = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      description = "IPv6 addresses for the tunnel interface";
    };

    gateway = lib.mkOption {
      type = lib.types.str;
      description = "IPv6 gateway address";
    };

    mtu = lib.mkOption {
      type = lib.types.str;
      default = "1480";
      description = "MTU bytes for the tunnel interface";
    };

    attachToInterface = lib.mkOption {
      type = lib.types.str;
      default = "eth0";
      description = "Network interface to attach the tunnel to";
    };

    localAddress = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Local IPv4 address for tunnel endpoint. Defaults to public.IPv4. Override when behind NAT.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.network.netdevs.henet = {
      netdevConfig = {
        Kind = "sit";
        Name = "henet";
        MTUBytes = cfg.mtu;
      };
      tunnelConfig = {
        Local = if cfg.localAddress != null then cfg.localAddress else LT.this.public.IPv4;
        Remote = cfg.remote;
        TTL = 255;
      };
    };

    systemd.network.networks = {
      henet = {
        address = cfg.addresses;
        gateway = [ cfg.gateway ];
        matchConfig.Name = "henet";
      };
      ${cfg.attachToInterface}.networkConfig.Tunnel = "henet";
    };
  };
}
