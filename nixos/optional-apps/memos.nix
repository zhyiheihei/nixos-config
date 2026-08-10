{
  LT,
  config,
  inputs,
  lib,
  ...
}:
{
  options.lantian.memos.storage = lib.mkOption {
    type = lib.types.str;
    default = "/var/lib/memos";
    description = "Storage path for Memos data";
  };

  config = {
    sops.secrets = {
      dex-memos-secret = {
        sopsFile = inputs.secrets + "/common/dex.yaml";
        key = "dex-memos-secret";
        mode = "0444";
      };
      memos-metapi-key = {
        sopsFile = inputs.secrets + "/uni-api/keys.yaml";
        key = "uni-api-admin-api-key";
        mode = "0444";
      };
    };

    networking.hosts."${LT.hosts.colocrossing.ltnet.IPv4}" = [
      "metapi.colocrossing.zhyi.cc"
    ];

    virtualisation.oci-containers.containers.memos = {
      image = "docker.io/neosmemo/memos:0.29.1";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.Memos}:${LT.portStr.Memos}" ];
      volumes = [ "${config.lantian.memos.storage}:/var/opt/memos" ];
      extraOptions = [
        "--add-host=metapi.colocrossing.zhyi.cc:${LT.hosts.colocrossing.ltnet.IPv4}"
      ];
      environment = {
        MEMOS_MODE = "prod";
        MEMOS_PORT = LT.portStr.Memos;
        MEMOS_INSTANCE_URL = "https://memos.${config.networking.hostName}.zhyi.cc";
        TZ = config.time.timeZone;
      };
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
