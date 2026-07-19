{
  config,
  ...
}:
let
  mkSubscriptionLocation = template: {
    extraConfig = ''
      include ${config.sops.templates."worker-vless2sub-token.nginx".path};
      default_type text/yaml;
      add_header Content-Disposition 'attachment; filename=mihomo.yaml';
      alias ${config.sops.templates.${template}.path};
    '';
  };
in
{
  # The subscription is static apart from the VLESS UUID. Rendering it through
  # SOPS avoids keeping Wrangler's development runtime and file watcher alive.
  sops.templates."worker-vless2sub-mihomo.yaml" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      mixed-port: 7890
      allow-lan: true
      mode: rule
      log-level: info
      ipv6: true

      proxies:
        - name: jpvm
          type: vless
          server: jp.zhyi.cc
          port: 443
          uuid: "${config.sops.placeholder.v2ray-key}"
          network: xhttp
          tls: true
          udp: true
          servername: jp.zhyi.cc
          client-fingerprint: chrome
          encryption: ""
          xhttp-opts:
            path: /ray
            host: jp.zhyi.cc
            mode: stream-up

      proxy-groups:
        - name: PROXY
          type: select
          proxies:
            - jpvm
            - DIRECT

      rules:
        - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
        - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
        - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
        - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
        - IP-CIDR,100.64.0.0/10,DIRECT,no-resolve
        - IP-CIDR6,fc00::/7,DIRECT,no-resolve
        - IP-CIDR6,fe80::/10,DIRECT,no-resolve
        - GEOIP,CN,DIRECT,no-resolve
        - MATCH,PROXY
    '';
  };

  sops.templates."worker-vless2sub-index.html" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      <!doctype html>
      <html lang="zh-CN">
        <head>
          <meta charset="utf-8">
          <meta name="viewport" content="width=device-width, initial-scale=1">
          <meta name="robots" content="noindex, nofollow">
          <title>Zh Yi Subscription</title>
          <style>
            :root { color-scheme: light dark; font-family: system-ui, sans-serif; }
            body { margin: 0; min-height: 100vh; display: grid; place-items: center; background: #111315; color: #f3f5f7; }
            main { width: min(680px, calc(100% - 40px)); }
            h1 { margin: 0 0 12px; font-size: 30px; letter-spacing: 0; }
            p { margin: 0 0 24px; color: #aeb6bf; }
            input { box-sizing: border-box; width: 100%; padding: 13px 14px; border: 1px solid #42484f; border-radius: 6px; background: #1b1f23; color: #e8edf2; font: 14px ui-monospace, monospace; }
            a { display: inline-block; margin-top: 16px; padding: 11px 16px; border-radius: 6px; background: #e8edf2; color: #111315; font-weight: 650; text-decoration: none; }
            a:hover { background: #ffffff; }
          </style>
        </head>
        <body>
          <main>
            <h1>Zh Yi Subscription</h1>
            <p>Mihomo 订阅</p>
            <input aria-label="Mihomo 订阅地址" readonly value="https://sub.zhyi.cc/mihomo.yaml?token=${config.sops.placeholder.v2ray-key}">
            <a href="https://sub.zhyi.cc/mihomo.yaml?token=${config.sops.placeholder.v2ray-key}">打开订阅</a>
          </main>
        </body>
      </html>
    '';
  };

  sops.templates."worker-vless2sub-jpvm.yaml" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      mixed-port: 7890
      allow-lan: true
      mode: rule
      log-level: info
      ipv6: true

      proxies:
        - name: jpvm
          type: vless
          server: jp.zhyi.cc
          port: 443
          uuid: "${config.sops.placeholder.v2ray-key}"
          network: xhttp
          tls: true
          udp: true
          servername: jp.zhyi.cc
          client-fingerprint: chrome
          encryption: ""
          xhttp-opts:
            path: /ray
            host: jp.zhyi.cc
            mode: stream-up

      proxy-groups:
        - name: PROXY
          type: select
          proxies:
            - jpvm
            - DIRECT

      rules:
        - GEOIP,CN,DIRECT,no-resolve
        - MATCH,PROXY
    '';
  };

  sops.templates."worker-vless2sub-token.nginx" = {
    owner = "nginx";
    group = "nginx";
    mode = "0440";
    content = ''
      if ($arg_token != "${config.sops.placeholder.v2ray-key}") {
        return 404;
      }
    '';
  };

  lantian.nginxVhosts."sub.zhyi.cc" = {
    locations = {
      "= /" = {
        enableOAuth = true;
        extraConfig = ''
          default_type text/html;
          alias ${config.sops.templates."worker-vless2sub-index.html".path};
        '';
      };
      "= /mihomo.yaml" = mkSubscriptionLocation "worker-vless2sub-mihomo.yaml";
      "= /jpvm.yaml" = mkSubscriptionLocation "worker-vless2sub-jpvm.yaml";
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
}
