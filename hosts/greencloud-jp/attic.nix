# 主机级 attic 部署（S3 后端为本机 VaultS3），详见 docs/agent/attic-s3-cache.md。
# 上游 nixos/optional-apps/attic.nix 面向作者的 Telnyx 存储，本机不导入。
{
  pkgs,
  lib,
  LT,
  config,
  inputs,
  ...
}:
{
  imports = [ ../../nixos/optional-apps/postgresql.nix ];

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

    lantian.nginxVhosts."attic.zhyi.xin" = {
      locations = {
        "/" = {
          proxyPass = "http://[::1]:${LT.portStr.Attic}";
          proxyNoTimeout = true;
        };
      };

      sslCertificate = "lets-encrypt-zhyi.xin";
      noIndex.enable = true;
    };
  };
}
