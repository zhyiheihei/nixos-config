{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  cfg = config.lantian.hubproxy;

  # Mirrors upstream src/config.toml defaults, with the listener bound to
  # loopback and the registered port; nginx vhosts expose it publicly.
  configFile = pkgs.writeText "hubproxy-config.toml" ''
    [server]
    host = "127.0.0.1"
    port = ${LT.portStr.HubProxy}
    fileSize = 2147483648
    enableH2C = false
    enableFrontend = true

    [rateLimit]
    # Home LAN devices share one public IP; raise the default 500/3h so a
    # multi-device docker pull storm is not throttled as one client.
    requestLimit = 2000
    periodHours = 3.0

    [security]
    whiteList = [
        "127.0.0.1",
        "127.0.0.2"
    ]
    blackList = []

    [access]
    whiteList = []
    blackList = []
    proxy = ""

    [download]
    maxImages = 10

    [registries]

    [registries."ghcr.io"]
    upstream = "ghcr.io"
    authHost = "ghcr.io/token"
    authType = "github"
    enabled = true

    [registries."gcr.io"]
    upstream = "gcr.io"
    authHost = "gcr.io/v2/token"
    authType = "google"
    enabled = true

    [registries."quay.io"]
    upstream = "quay.io"
    authHost = "quay.io/v2/auth"
    authType = "quay"
    enabled = true

    [registries."registry.k8s.io"]
    upstream = "registry.k8s.io"
    authHost = "registry.k8s.io"
    authType = "anonymous"
    enabled = true

    [tokenCache]
    enabled = true
    defaultTTL = "20m"
  '';
in
{
  options.lantian.hubproxy.enable = lib.mkEnableOption "HubProxy Docker/GitHub/HuggingFace acceleration proxy";

  config = lib.mkIf cfg.enable {
    systemd.services.hubproxy = {
      description = "HubProxy Docker/GitHub/HuggingFace acceleration proxy";
      after = [
        "network-online.target"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      environment.CONFIG_PATH = configFile;

      serviceConfig = LT.serviceHarden // {
        Type = "simple";
        User = "hubproxy";
        Group = "hubproxy";
        RuntimeDirectory = "hubproxy";
        WorkingDirectory = "/run/hubproxy";
        ExecStart = "${inputs.zhyi-packages.packages.${pkgs.system}.hubproxy}/bin/hubproxy";
        Restart = "always";
        RestartSec = "5";
      };
    };

    users.users.hubproxy = {
      group = "hubproxy";
      isSystemUser = true;
    };
    users.groups.hubproxy = { };

    # Private-only: reachable via ZeroTier/LTNET (resolved through the home
    # edge's hosts override), not from the public internet.
    lantian.nginxVhosts."hub.${config.networking.hostName}.zhyi.xin" = {
      locations."/" = {
        proxyPass = "http://127.0.0.1:${LT.portStr.HubProxy}";
        proxyNoTimeout = true;
      };

      accessibleBy = "private";
      sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.xin";
      noIndex.enable = true;
    };
  };
}
