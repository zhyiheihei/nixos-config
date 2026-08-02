{ LT, ... }:
let
  qnapAddress = "192.168.0.40";
in
{
  networking.hosts."${LT.this.interconnect.IPv4}" = [ "vaults3.zhyi.cc" ];

  lantian.nginxVhosts."vaults3.zhyi.cc" = {
    extraConfig = ''
      listen 0.0.0.0:8443 ssl;
      listen [::]:8443 ssl;
    '';
    locations."/" = {
      proxyPass = "http://${qnapAddress}:9000";
      proxyOverrideHost = "$http_host";
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
}
