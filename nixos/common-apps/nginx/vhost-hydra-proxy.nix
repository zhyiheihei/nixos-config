{ LT, ... }:
{
  lantian.nginxVhosts = {
    "hydra.zhyi.cc" = {
      locations = {
        "/" = {
          proxyPass = "http://${LT.hosts.pve-5700u.ltnet.IPv4}:${LT.portStr.Hydra}";
          extraConfig = ''
            limit_req zone=slow burst=20 nodelay;
            limit_req_status 429;
          '';
        };
      };

      blockDotfiles = false;
      enableCommonLocationOptions = false;
      sslCertificate = "zerossl-zhyi.cc";
      noIndex.enable = true;
    };
  };
}
