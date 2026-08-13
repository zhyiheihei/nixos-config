{ LT, ... }:
{
  networking.hosts."${LT.this.interconnect.IPv4}" = [ "vaults3.zhyi.cc" ];

  # VaultS3 runs natively on the router (192.168.0.1:9000); opi5p keeps the
  # public TLS front for the 8443 compatibility endpoint (router DNATs
  # 8443 -> opi5p:443).
  lantian.nginxVhosts."vaults3.zhyi.cc" = {
    locations."/" = {
      proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:9000";
      proxyOverrideHost = "$http_host";
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
}
