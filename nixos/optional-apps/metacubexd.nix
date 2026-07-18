{
  LT,
  config,
  inputs,
  lib,
  ...
}:
{
  options.lantian.metacubexd.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/metacubexd";
    description = "Storage path for MetaCubeXD data";
  };

  config = {
    sops.secrets = {
      metacubexd-clash-secret = {
        sopsFile = inputs.secrets + "/common/personal-apps.yaml";
        key = "METACUBEXD_CLASH_SECRET";
      };
      metacubexd-control-token = {
        sopsFile = inputs.secrets + "/common/personal-apps.yaml";
        key = "METACUBEXD_CONTROL_TOKEN";
      };
    };

    sops.templates.metacubexd-env.content = ''
      CLASH_SECRET=${config.sops.placeholder.metacubexd-clash-secret}
      CONTROL_TOKEN=${config.sops.placeholder.metacubexd-control-token}
    '';

    virtualisation.oci-containers.containers.metacubexd = {
      image = "ghcr.io/metacubex/metacubexd-server:latest";
      labels."io.containers.autoupdate" = "registry";
      ports = [
        # Preserve the legacy OpenClash-compatible LAN endpoint.
        "${LT.this.interconnect.IPv4}:7892:7892"
        "127.0.0.1:${LT.portStr.MetaCubeXD.Control}:8082"
        "127.0.0.1:${LT.portStr.MetaCubeXD.ClashAPI}:9092"
      ];
      volumes = [ "${config.lantian.metacubexd.storage}:/data" ];
      environment = {
        CLASH_API_PORT = "9092";
        CONTROL_PORT = "8082";
        DATA_DIR = "/data";
        MIHOMO_BIN = "/usr/local/bin/mihomo";
        MIXED_PORT = "7892";
        TZ = config.time.timeZone;
        UI_DIST = "/app/ui-dist";
      };
      environmentFiles = [ config.sops.templates.metacubexd-env.path ];
    };

    systemd.tmpfiles.settings.metacubexd."${config.lantian.metacubexd.storage}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts = {
      "metacubexd.${config.networking.hostName}.zhyi.cc" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.MetaCubeXD.Control}";
          proxyWebsockets = true;
        };
        accessibleBy = "private";
        sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
        noIndex.enable = true;
      };
      "metacubexd.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.MetaCubeXD.Control}";
          proxyWebsockets = true;
        };
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
  };
}
