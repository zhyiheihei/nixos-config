{ LT, ... }:
{
  services.prometheus.exporters = {
    node = {
      enable = !(LT.this.hasTag LT.tags.client);
      port = LT.port.Prometheus.NodeExporter;
      # Pre-enrollment images do not own their derived LTNET address yet. Bind
      # locally until the real ZeroTier node ID is committed and authorized.
      listenAddress = if LT.this.zerotier == null then "127.0.0.1" else LT.this.ltnet.IPv4;
      enabledCollectors = [ "systemd" ];
    };
  };
}
