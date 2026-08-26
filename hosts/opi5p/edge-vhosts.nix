{ LT, lib, config, ... }:
let
  # 家庭宽带 WAN 443 被运营商封禁，公网 TLS 入口走 8443。nginx 的 vhost
  # 每 HTTPS 端口只能有一个，这里基于 lantian.nginxVhosts 重新生成
  # virtualHosts，给每个启用 TLS 的 vhost 追加 8443 监听（仅本主机生效）。
  publicHttpsPort = 8443;
  with8443 =
    v:
    let
      cfg = v._config;
      baseListen = cfg.listen; # lib.mkForce 的 override 包装，取 content
      existing = baseListen.content or baseListen;
      hasTLS = lib.any (l: lib.elem "ssl" (l.extraParameters or [ ])) existing;
    in
    if hasTLS then
      cfg // {
        listen = lib.mkForce (
          existing ++ [
            {
              addr = "0.0.0.0";
              port = publicHttpsPort;
              extraParameters = [ "ssl" ];
            }
          ]
        );
      }
    else
      cfg;
in
{
  # 让 8443 由 nginx 原生监听（router 直通到本机 8443，不再转换到 443）。
  services.nginx.virtualHosts = lib.mkForce (
    lib.mapAttrs (_: with8443) config.lantian.nginxVhosts
  );

  networking.hosts."${LT.this.interconnect.IPv4}" = [
    "vaults3.zhyi.xin"
    "jellyfin.zhyi.xin"
    "qnap.zhyi.xin"
    "tachidesk.zhyi.xin"
  ];

  # VaultS3 runs natively on the router (192.168.0.1:9000); opi5p keeps the
  # public TLS front for the 8443 compatibility endpoint (router DNATs
  # 8443 -> opi5p:8443).
  lantian.nginxVhosts."vaults3.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://${LT.hosts.router.interconnect.IPv4}:9000";
      proxyOverrideHost = "$http_host";
      proxyNoTimeout = true;
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # 家宽 WAN 443 被运营商封禁，router 把公网 8443 DNAT 直通 opi5p:8443（端口不变）。
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
    sslCertificate = "zerossl-zhyi.xin";
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
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # Memos / FileCodeBox / Sun Panel 迁到 dragon-q8b（Qualcomm SC8280XP）。
  # opi5p 保持公网 8443 TLS 前沿，回源 dragon-q8b 内网 443。
  lantian.nginxVhosts."memos.zhyi.xin" = {
    locations."/" = {
      proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
      proxyOverrideHost = "memos.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name memos.zhyi.xin;
      '';
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."filebox.zhyi.xin" = {
    locations."/" = {
      proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
      proxyOverrideHost = "filebox.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name filebox.zhyi.xin;
      '';
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."index.zhyi.xin" = {
    locations."/" = {
      proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
      proxyOverrideHost = "index.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name index.zhyi.xin;
      '';
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  lantian.nginxVhosts."index-helper.zhyi.xin" = {
    locations."/" = {
      proxyPass = "https://${LT.hosts.dragon-q8b.interconnect.IPv4}";
      proxyOverrideHost = "index-helper.zhyi.xin";
      proxyWebsockets = true;
      proxyNoTimeout = true;
      extraConfig = ''
        proxy_ssl_server_name on;
        proxy_ssl_name index-helper.zhyi.xin;
      '';
    };
    sslCertificate = "zerossl-zhyi.xin";
    noIndex.enable = true;
  };

  # Tachidesk 公开 vhost 由 tachidesk.nix（media-download-chain import）提供，
  # 本文件不重复定义，避免 proxyPass 冲突。
}