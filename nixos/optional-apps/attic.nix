{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
{
  imports = [ ./postgresql.nix ];

  options.lantian.attic.hostVhost = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = ''
      Also serve the cache under attic.''${config.networking.hostName}.zhyi.xin.
      Mirrors upstream's per-host attic vhost pattern for multi-region caches;
      the DNS record and certificate must be provisioned separately.
    '';
  };

  config = {
    sops.secrets.attic-credentials = {
      sopsFile = inputs.secrets + "/common/attic.yaml";
      owner = "atticd";
      group = "atticd";
    };

    services.atticd = {
      enable = true;
      package = pkgs.nur-xddxdd.lantianCustomized.attic-telnyx-compatible;
      environmentFile = config.sops.secrets.attic-credentials.path;
      mode = "monolithic";
      settings = lib.mkForce {
        listen = "[::1]:${LT.portStr.Attic}";
        api-endpoint = "https://attic.zhyi.xin/";
        substituter-endpoint = "https://attic.zhyi.xin/";
        database = {
          url = "postgres://atticd?host=/run/postgresql&user=atticd";
          heartbeat = true;
        };
        require-proof-of-possession = false;
        storage = {
          type = "s3";
          region = "us-east-1";
          bucket = "nix-cache";
          # S3 后端与 atticd 同机（greencloud-jp 的 VaultS3，nginx TLS 443）。
          # 用公网 endpoint 而非 loopback，保证 S3 直链下载的 presigned URL
          # 对客户端可达。2026-09 前曾指向家中 vaults3（home-ddns 8443），
          # 跨境大对象上传会被切断导致 CI push-cache 失败，已切回本机。
          endpoint = "https://s3.zhyi.xin";
        };
        # Disable chunking to use S3 direct download.
        chunking = {
          nar-size-threshold = 0;
          min-size = 16384;
          avg-size = 65536;
          max-size = 262144;
        };
        compression = {
          type = "zstd";
          level = 9;
        };
        garbage-collection = {
          interval = "12 hours";
          default-retention-period = "3 month";
        };
      };
    };

    systemd.services.atticd.serviceConfig = LT.serviceHarden // {
      DynamicUser = lib.mkForce false;
      StateDirectory = lib.mkForce "";
    };

    users.users.atticd = {
      group = "atticd";
      isSystemUser = true;
    };
    users.groups.atticd = { };

    services.postgresql = {
      ensureDatabases = [ "atticd" ];
      ensureUsers = [
        {
          name = "atticd";
          ensureDBOwnership = true;
        }
      ];
    };

    lantian.nginxVhosts = {
      "attic.zhyi.xin" = {
        locations = {
          "/" = {
            proxyPass = "http://[::1]:${LT.portStr.Attic}";
            proxyNoTimeout = true;
          };
        };

        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
    }
    // lib.optionalAttrs config.lantian.attic.hostVhost {
      "attic.${config.networking.hostName}.zhyi.xin" = {
        locations."/" = {
          proxyPass = "http://[::1]:${LT.portStr.Attic}";
          proxyNoTimeout = true;
        };

        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
    };
  };
}
