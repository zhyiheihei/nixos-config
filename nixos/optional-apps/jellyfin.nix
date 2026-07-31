{
  LT,
  pkgs,
  config,
  utils,
  ...
}:
let
  proxy = "http://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.SocksClient}";
  noProxy = "localhost,127.0.0.1,::1,192.168.0.0/16,.zhyi.cc,.zhyi.xin";

  loggingConf = {
    Serilog = {
      Using = [ "Serilog.Sinks.Console" ];
      MinimumLevel = "Warning";
      WriteTo = [ { Name = "Console"; } ];
      Enrich = [
        "FromLogContext"
        "WithMachineName"
        "WithThreadId"
      ];
      Properties.Application = "Jellyfin";
    };
  };

  netns = config.lantian.netns.jellyfin;
in
{
  services.jellyfin.enable = true;

  lantian.netns.jellyfin.ipSuffix = "48";

  lantian.nginxVhosts = {
    "jellyfin.zhyi.xin" = {
      locations = {
        "/" = {
          proxyPass = "http://unix:/run/jellyfin/socket";
        };
        "= /web/" = {
          proxyPass = "http://unix:/run/jellyfin/socket:/web/index.html";
        };
      };

      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
    "jellyfin.localhost" = {
      listenHTTP.enable = true;
      listenHTTPS.enable = false;

      locations = {
        "/" = {
          proxyPass = "http://unix:/run/jellyfin/socket";
        };
        "= /web/" = {
          proxyPass = "http://unix:/run/jellyfin/socket:/web/index.html";
        };
      };

      noIndex.enable = true;
      accessibleBy = "localhost";
    };
  };

  systemd.services.jellyfin = netns.bind {
    environment = {
      JELLYFIN_kestrel__socket = "true";
      JELLYFIN_kestrel__socketPath = "/run/jellyfin/socket";
      JELLYFIN_kestrel__socketPermissions = "0777";
      JELLYFIN_PublishedServerUrl = "https://jellyfin.zhyi.xin";
      HTTP_PROXY = proxy;
      HTTPS_PROXY = proxy;
      NO_PROXY = noProxy;
      http_proxy = proxy;
      https_proxy = proxy;
      no_proxy = noProxy;
    };
    serviceConfig = {
      RuntimeDirectory = "jellyfin";
      ExecStartPre = pkgs.writeShellScript "jellyfin-pre" ''
        ${utils.genJqSecretsReplacementSnippet loggingConf "/var/lib/jellyfin/config/logging.json"}
      '';
    };
  };

  users.users.jellyfin.extraGroups = [
    "video"
    "render"
  ];
}
