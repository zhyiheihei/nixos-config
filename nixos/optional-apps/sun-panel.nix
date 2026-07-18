{ LT, config, lib, ... }:
{
  options.lantian.sunPanel.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/sun-panel";
    description = "Storage path for Sun-Panel data";
  };

  config = {
    virtualisation.oci-containers.containers = {
      sun-panel = {
        image = "docker.io/hslr/sun-panel:1.8.1";
        labels."io.containers.autoupdate" = "registry";
        ports = [ "127.0.0.1:${LT.portStr.SunPanel}:3002" ];
        volumes = [
          "${config.lantian.sunPanel.storage}:/app/conf"
          "/var/run/docker.sock:/var/run/docker.sock"
        ];
      };
      sun-panel-helper = {
        image = "docker.io/madrays/sun-panel-helper:latest";
        labels."io.containers.autoupdate" = "registry";
        ports = [ "127.0.0.1:${LT.portStr.SunPanelHelper}:80" ];
        volumes = [ "${config.lantian.sunPanel.storage}/custom:/app/backend/custom" ];
      };
    };

    systemd.tmpfiles.settings.sun-panel."${config.lantian.sunPanel.storage}"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts = {
      "index.zhyi.xin" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.SunPanel}";
          enableOAuth = true;
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "index-helper.zhyi.xin" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.SunPanelHelper}";
          enableOAuth = true;
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "sun-panel.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.SunPanel}";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
      "sun-panel-helper.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.SunPanelHelper}";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
  };
}
