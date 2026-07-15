{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  workerSource = pkgs.fetchurl {
    urls = [
      "https://ghfast.top/https://raw.githubusercontent.com/cmliu/WorkerVless2sub/304608e4b23495d347c4d8a1b3d741c382eda093/_worker.js"
      "https://raw.githubusercontent.com/cmliu/WorkerVless2sub/304608e4b23495d347c4d8a1b3d741c382eda093/_worker.js"
    ];
    hash = "sha256-VOtL1Ui7YC5hqx+PS7rezXmX2cEIgLwPP0t2EUWhZX0=";
  };

  wranglerConfig = pkgs.writeText "worker-vless2sub-wrangler.toml" ''
    name = "vless2sub-worker"
    main = "wrapper.js"
    compatibility_date = "2025-09-07"
    keep_vars = true
  '';

  workerWrapper = pkgs.writeText "worker-vless2sub-wrapper.js" ''
    import upstream from "./_worker.js";

    function subscriptionPage(request, env) {
      const subscriptionUrl = new URL("/mihomo.yaml", request.url);
      subscriptionUrl.searchParams.set("token", env.TOKEN);
      const escapedUrl = subscriptionUrl.toString()
        .replaceAll("&", "&amp;")
        .replaceAll('"', "&quot;")
        .replaceAll("<", "&lt;")
        .replaceAll(">", "&gt;");

      return `<!doctype html>
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
          <input aria-label="Mihomo 订阅地址" readonly value="''${escapedUrl}">
          <a href="''${escapedUrl}">打开订阅</a>
        </main>
      </body>
    </html>`;
    }

    function mihomoConfig(env) {
      return `mixed-port: 7890
    allow-lan: true
    mode: rule
    log-level: info
    ipv6: true

    proxies:
      - name: twvm
        type: vless
        server: tw.zhyi.cc
        port: 443
        uuid: "''${env.UUID}"
        network: xhttp
        tls: true
        udp: true
        servername: tw.zhyi.cc
        client-fingerprint: chrome
        encryption: ""
        xhttp-opts:
          path: /ray
          host: tw.zhyi.cc
          mode: stream-up
      - name: jpvm
        type: vless
        server: jp.zhyi.cc
        port: 443
        uuid: "''${env.UUID}"
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
          - AUTO
          - twvm
          - jpvm
          - DIRECT
      - name: AUTO
        type: url-test
        proxies:
          - twvm
          - jpvm
        url: https://www.gstatic.com/generate_204
        interval: 300

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
    `;
    }

    export default {
      async fetch(request, env, context) {
        const url = new URL(request.url);
        if (url.pathname === "/") {
          if (!env.TOKEN) {
            return new Response("Subscription is not configured", { status: 503 });
          }
          return new Response(subscriptionPage(request, env), {
            headers: {
              "content-type": "text/html; charset=utf-8",
              "cache-control": "no-store",
            },
          });
        }

        if (url.pathname === "/mihomo.yaml") {
          if (!env.TOKEN || url.searchParams.get("token") !== env.TOKEN) {
            return new Response("Not Found", { status: 404 });
          }

          return new Response(mihomoConfig(env), {
            headers: {
              "content-type": "text/yaml; charset=utf-8",
              "content-disposition": "attachment; filename=mihomo.yaml",
              "profile-update-interval": "6",
              "cache-control": "no-store",
            },
          });
        }

        return upstream.fetch(request, env, context);
      },
    };
  '';
in
{
  sops.templates."worker-vless2sub.dev-vars" = {
    owner = "worker-vless2sub";
    group = "worker-vless2sub";
    mode = "0400";
    content = ''
      TOKEN="${config.sops.placeholder.v2ray-key}"
      HOST="tw.zhyi.cc"
      UUID="${config.sops.placeholder.v2ray-key}"
      PATH="/ray"
      SNI="tw.zhyi.cc"
      TYPE="xhttp"
      LINK="vless://${config.sops.placeholder.v2ray-key}@tw.zhyi.cc:443?security=tls&sni=tw.zhyi.cc&fp=chrome&type=xhttp&host=tw.zhyi.cc&path=%2Fray&mode=stream-up&encryption=none#twvm"
      SUBAPI="https://sub.cmliussss.com"
      SUBNAME="Zh Yi Subscription"
    '';
  };

  systemd.services.worker-vless2sub = {
    description = "WorkerVless2sub subscription generator";
    after = [ "network-online.target" ];
    wants = [ "network-online.target" ];
    wantedBy = [ "multi-user.target" ];
    environment = {
      CI = "true";
      HOME = "/var/lib/worker-vless2sub";
      WRANGLER_SEND_METRICS = "false";
    };
    script = ''
      cp ${workerSource} "$RUNTIME_DIRECTORY/_worker.js"
      cp ${workerWrapper} "$RUNTIME_DIRECTORY/wrapper.js"
      cp ${wranglerConfig} "$RUNTIME_DIRECTORY/wrangler.toml"
      ln -s ${config.sops.templates."worker-vless2sub.dev-vars".path} "$RUNTIME_DIRECTORY/.dev.vars"
      cd "$RUNTIME_DIRECTORY"
      exec ${lib.getExe pkgs.wrangler} dev \
        --config "$RUNTIME_DIRECTORY/wrangler.toml" \
        --local \
        --ip 127.0.0.1 \
        --port ${LT.portStr.WorkerVless2sub}
    '';
    serviceConfig = LT.serviceHarden // {
      User = "worker-vless2sub";
      Group = "worker-vless2sub";
      MemoryDenyWriteExecute = false;
      RestrictAddressFamilies = [
        "AF_UNIX"
        "AF_INET"
        "AF_INET6"
        "AF_NETLINK"
      ];
      RuntimeDirectory = "worker-vless2sub";
      StateDirectory = "worker-vless2sub";
      Restart = "always";
      RestartSec = 5;
    };
  };

  users.users.worker-vless2sub = {
    group = "worker-vless2sub";
    isSystemUser = true;
  };
  users.groups.worker-vless2sub = { };

  lantian.nginxVhosts."sub.zhyi.cc" = {
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.WorkerVless2sub}";
        enableOAuth = true;
      };
      "= /mihomo.yaml" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.WorkerVless2sub}";
      };
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
}
