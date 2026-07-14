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
    main = "_worker.js"
    compatibility_date = "2025-09-07"
    keep_vars = true
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
    locations."/" = {
      proxyPass = "http://127.0.0.1:${LT.portStr.WorkerVless2sub}";
    };
    sslCertificate = "lets-encrypt-zhyi.cc";
    noIndex.enable = true;
  };
}
