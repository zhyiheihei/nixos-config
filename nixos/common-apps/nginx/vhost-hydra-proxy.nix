{ LT, ... }:
{
  lantian.nginxVhosts = {
    "hydra.zhyi.cc" = {
      locations = {
        "/" = {
          proxyPass = "http://${LT.hosts.pve-5700u.interconnect.IPv4}:${LT.portStr.Hydra}";
          extraConfig = ''
            limit_req zone=slow burst=20 nodelay;
            limit_req_status 429;
            proxy_set_header X-Forwarded-Host $host;
            proxy_set_header X-Forwarded-Port 443;
          '';
        };
      };

      blockDotfiles = false;
      enableCommonLocationOptions = false;
      sslCertificate = "lets-encrypt-zhyi.cc";
      noIndex.enable = true;
    };
  };
}
