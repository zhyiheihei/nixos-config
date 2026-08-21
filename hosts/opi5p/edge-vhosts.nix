{ LT, ... }:
{
  networking.hosts."${LT.this.interconnect.IPv4}" = [
    "vaults3.zhyi.xin"
    "jellyfin.zhyi.xin"
    "qnap.zhyi.xin"
    "tachidesk.zhyi.xin"
  ];

  # VaultS3 runs natively on the router (192.168.0.1:9000); opi5p keeps the
  # public TLS front for the 8443 compatibility endpoint (router DNATs
  # 8443 -> opi5p:443).
  lantian.nginxVhosts."vaults3.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:9000";
      proxyOverrideHost = "$http_host";
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  # 家宽 WAN 443 被运营商封禁，router 把公网 8443 DNAT 到 opi5p:443。
  # 这三个域名解析到 home-ddns（家宽 IP），公网只能经 8443 进入，
  # 所以 TLS 前沿必须落在 opi5p（而非原本只监听家内 443 的 rock5c）。
  # 后端沿用各服务现有 HTTP 中转 vhost，不回源公网 DNS，避免环路。

  # Jellyfin 本体迁到 macmini（192.168.0.54，VideoToolbox 硬解），直接监听
  # HTTP 8096。mac 不装 nginx（nix-darwin 无 services.nginx/nginxVhosts），
  # opi5p 保持公网 TLS 前沿，回源指 mac。认证为 Jellyfin 自带登录，无 basicAuth。
  lantian.nginxVhosts."jellyfin.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://${LT.hosts.macmini.interconnect.IPv4}:8096";
      proxyOverrideHost = "$http_host";
      proxyWebsockets = true;
      proxyNoTimeout = true;
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  # QNAP NAS 管理界面，与 opi5p 同网段，直接回源 NAS 自身。
  # 认证与 rock5c 的 qnap.zhyi.xin 一致（无 basicAuth，QNAP 自带登录）。
  lantian.nginxVhosts."qnap.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://192.168.0.40:8080";
      proxyOverrideHost = "$http_host";
      proxyWebsockets = true;
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  # Tachidesk 公开 vhost 由 tachidesk.nix（media-download-chain import）提供，
  # 本文件不重复定义，避免 proxyPass 冲突。
}