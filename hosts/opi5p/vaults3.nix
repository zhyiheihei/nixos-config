{ LT, ... }:
let
  qnapAddress = "192.168.0.40";
in
{
  networking.hosts."${LT.this.interconnect.IPv4}" = [ "vaults3.zhyi.cc" ];

  lantian.nginxVhosts."vaults3.zhyi.cc" = {
    locations."/" = {
      proxyPass = "http://${qnapAddress}:9000";
      proxyOverrideHost = "$http_host";
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };

  # QNAP NAS web UI, reachable from the public 8443 entry (router DNATs
  # 8443 -> opi5p:443) just like the other home services.
  lantian.nginxVhosts."qnap.zhyi.cc" = {
    locations."/" = {
      proxyPass = "http://${qnapAddress}:8080";
      proxyWebsockets = true;
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
}
