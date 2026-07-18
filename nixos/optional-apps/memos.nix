{ LT, config, lib, ... }:
{
  options.lantian.memos.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/memos";
    description = "Storage path for Memos data";
  };

  config = {
    virtualisation.oci-containers.containers.memos = {
      image = "docker.io/neosmemo/memos:0.29.1";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.Memos}:${LT.portStr.Memos}" ];
      volumes = [ "${config.lantian.memos.storage}:/var/opt/memos" ];
      environment.MEMOS_PORT = LT.portStr.Memos;
    };

    systemd.tmpfiles.settings.memos."${config.lantian.memos.storage}"."d" = {
      mode = "0755";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts = {
      "memos.${config.networking.hostName}.zhyi.cc" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${LT.portStr.Memos}";
          enableOAuth = true;
        };
        accessibleBy = "private";
        sslCertificate = "lets-encrypt-${config.networking.hostName}.zhyi.cc";
        noIndex.enable = true;
      };
      "memos.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/".proxyPass = "http://127.0.0.1:${LT.portStr.Memos}";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
  };
}
