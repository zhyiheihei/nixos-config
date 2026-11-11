{ LT, ... }:
{
  services.prometheus.exporters.node-cert = {
    enable = true;
    port = LT.port.Prometheus.NodeCertExporter;
    listenAddress = LT.this.ltnet.IPv4;
    paths = [ ];
    includeGlobs = [ "/nix/sync-servers/acme/*/cert.pem" ];
    # 已退役的证书族：不再续期（无 acme timer）也无任何 vhost 引用，
    # 同步过来的旧文件却已过期，会让 ssl_certificate_expiry 永久告警。
    excludeGlobs = [
      "/nix/sync-servers/acme/zerossl-xn--gmqs02au1c935d.pub-*/cert.pem"
      "/nix/sync-servers/acme/lets-encrypt-letsencrypt-ssl.zhyi.xin-*/cert.pem"
      "/nix/sync-servers/acme/lets-encrypt-test-letsencrypt-test-ssl.zhyi.xin-*/cert.pem"
    ];
  };

  systemd.services."prometheus-node-cert-exporter".serviceConfig = {
    RestartSec = "5s";
    # Reads ACME cert files
    BindReadOnlyPaths = [ "/nix/sync-servers" ];
  };
  lantian.harden.prometheus-node-cert-exporter.enable = true;

  lantian.firewall.zones = {
    LTNET.tcpPorts."${LT.portStr.Prometheus.NodeCertExporter}".type = "local";
  };
}
