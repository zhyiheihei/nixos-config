{
  inputs,
  config,
  lib,
  LT,
  pkgs,
  ...
}:
let
  ########################################
  # VaultS3 S3 网关（s3.zhyi.xin）
  ########################################

  vaults3Pkg = inputs.zhyi-packages.packages.${pkgs.system}.vaults3;
  vaults3Config = pkgs.writeText "vaults3.yaml" ''
    server:
      address: "127.0.0.1"
      port: 9000
    storage:
      data_dir: /data/vaults3-data
      metadata_dir: /nix/persistent/var/lib/vaults3
  '';
in
{
  imports = [
    ../../nixos/server.nix

    ./hardware-configuration.nix

    # SFTP 备份端点（internal-sftp chroot，chroot 目录改到 1T 数据盘）。
    ../../nixos/optional-apps/sftp-server.nix

    # Gitea（自 greencloud 迁入，2026-08-29；模块自带 mysql 依赖）。
    ../../nixos/optional-apps/gitea

    # Nextcloud：数据库用本机 MariaDB（上游 oci 类型连的是作者的 Oracle
    # ADB），OIDC 走 volcengine 的 Dex。
    ./nextcloud.nix

    # Syncthing 同步节点（自 greencloud 移交，机群常在线异地端）。
    ../../nixos/optional-apps/syncthing

    # Attic 二进制缓存（S3 后端为本机 VaultS3，详见 docs/agent/attic-s3-cache.md）。
    ./attic.nix
  ];

  # Syncthing 存储放 1T 数据盘（默认值在 40G 系统盘上放不下）。
  lantian.syncthing.storage = "/data/syncthing";

  # Obsidian vault 固定目录，与 opi5p Ignis vault 同名，方便 Syncthing 对接。
  systemd.tmpfiles.settings.syncthing."/data/syncthing/Notes"."d" = {
    mode = "755";
    user = "syncthing";
    group = "syncthing";
  };

  # 本机是机群的异地备份目标，不再向外推送自身备份。
  lantian.backup.schedule = null;

  # sftp chroot 改到 1T 数据盘：ChrootDirectory 要求整条路径 root 属主，
  # 故 home 本身 root 属主，数据写进内部 sftp 可写的 backups/restic 子目录。
  users.users.sftp = {
    home = lib.mkForce "/data/sftp-server";
    createHome = lib.mkForce false;
  };

  systemd.tmpfiles.settings.sftp-backup = {
    "/data/sftp-server"."d" = {
      user = "root";
      group = "root";
      mode = "755";
    };
    "/data/sftp-server/backups"."d" = {
      user = "sftp";
      group = "sftp";
      mode = "755";
    };
    "/data/sftp-server/backups/restic"."d" = {
      user = "sftp";
      group = "sftp";
      mode = "755";
    };
    # storagebox 双备份仓库根（minimal-components/backup/common.nix）
    "/data/sftp-server/backups/rustic-storagebox"."d" = {
      user = "sftp";
      group = "sftp";
      mode = "755";
    };
  };

  # cn-accel 出口节点：默认 vhost 的 /ray 走真证书（同 tencent；xray 服务由
  # cn-accel 标签经 server-apps/v2ray.nix 启用）。
  lantian.nginxVhosts."greencloud-jp.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  # Gitea LFS/附件存储指向本机 VaultS3（router 上的旧实例已停摆）。
  services.gitea.settings.storage = {
    MINIO_ENDPOINT = lib.mkForce "s3.zhyi.xin:443";
    MINIO_BUCKET = lib.mkForce "gitea";
    MINIO_LOCATION = lib.mkForce "east-1";
    MINIO_USE_SSL = lib.mkForce true;
    SERVE_DIRECT = lib.mkForce false;
  };

  # VaultS3 S3 网关：数据放 1T 数据盘，仅监听 loopback，由 nginx 反代
  # s3.zhyi.xin（泛域名证书）。与 router 上的实例共用机群统一凭据约定。
  users.users.vaults3 = {
    isSystemUser = true;
    group = "vaults3";
  };
  users.groups.vaults3 = { };

  sops.templates.vaults3-credentials = {
    content = ''
      VAULTS3_ACCESS_KEY=zhyi
      VAULTS3_SECRET_KEY=${config.sops.placeholder.default-pw}
    '';
    mode = "0400";
    owner = "vaults3";
    group = "vaults3";
  };

  # atticd 专用 IAM key（vaults3-atticd），经第二个 EnvironmentFile 覆盖
  # 默认 AWS_*（同名变量后者生效）。
  sops.secrets.vaults3-atticd = {
    sopsFile = inputs.secrets + "/common/attic.yaml";
    owner = "atticd";
    group = "atticd";
  };

  systemd.services.atticd.serviceConfig.EnvironmentFile = lib.mkForce [
    config.sops.secrets.attic-credentials.path
    config.sops.secrets.vaults3-atticd.path
  ];

  systemd.tmpfiles.settings.vaults3 = {
    "/nix/persistent/var/lib/vaults3".d = {
      mode = "0700";
      user = "vaults3";
      group = "vaults3";
    };
    "/data/vaults3-data".d = {
      mode = "0700";
      user = "vaults3";
      group = "vaults3";
    };
  };

  systemd.services.vaults3 = {
    description = "VaultS3 S3-compatible object storage";
    wantedBy = [ "multi-user.target" ];
    after = [
      "data.mount"
      "network.target"
      "sops-install-secrets.service"
    ];
    requires = [ "data.mount" ];
    unitConfig.RequiresMountsFor = [ "/data/vaults3-data" ];
    environment = {
      VAULTS3_DATA_DIR = "/data/vaults3-data";
      VAULTS3_METADATA_DIR = "/nix/persistent/var/lib/vaults3";
    };
    serviceConfig = LT.serviceHarden // {
      Type = "simple";
      User = "vaults3";
      Group = "vaults3";
      EnvironmentFile = config.sops.templates.vaults3-credentials.path;
      ExecStart = "${vaults3Pkg}/bin/vaults3 -config ${vaults3Config}";
      Restart = "on-failure";
      RestartSec = "5";
      ReadWritePaths = [
        "/data/vaults3-data"
        "/nix/persistent/var/lib/vaults3"
      ];
    };
  };

  # nix-cache 桶不由 VaultS3 自动创建：幂等 oneshot 建桶（官方 S3 API、
  # root 凭据），atticd 排在其后。
  systemd.services.vaults3-init-nix-cache = {
    description = "Ensure nix-cache bucket exists for atticd";
    wantedBy = [ "multi-user.target" ];
    after = [ "vaults3.service" ];
    requires = [ "vaults3.service" ];
    serviceConfig = LT.serviceHarden // {
      Type = "oneshot";
      RemainAfterExit = true;
      DynamicUser = lib.mkForce false;
      User = "vaults3";
      Group = "vaults3";
      EnvironmentFile = config.sops.templates.vaults3-credentials.path;
      ExecStart = pkgs.writeShellScript "vaults3-init-nix-cache" ''
        export PATH=${pkgs.awscli2}/bin:$PATH
        # EnvironmentFile 里是 VaultS3 CLI 约定的 VAULTS3_* 变量名，
        # awscli 需要 AWS_*：在此映射，凭据本身不变。
        export AWS_ACCESS_KEY_ID="$VAULTS3_ACCESS_KEY"
        export AWS_SECRET_ACCESS_KEY="$VAULTS3_SECRET_KEY"
        export AWS_DEFAULT_REGION=us-east-1
        if ! aws --endpoint-url http://127.0.0.1:9000 s3api head-bucket --bucket nix-cache >/dev/null 2>&1; then
          aws --endpoint-url http://127.0.0.1:9000 s3api create-bucket --bucket nix-cache
        fi
      '';
    };
  };

  systemd.services.atticd = {
    after = [ "vaults3-init-nix-cache.service" ];
    wants = [ "vaults3-init-nix-cache.service" ];
  };

  lantian.nginxVhosts."s3.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:9000";
      proxyWebsockets = true;
      extraConfig = ''
        client_max_body_size 0;
      '';
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  # 该机房 DHCPv4 拿不到租约，v4/v6 均静态（网关为救援环境实测值）。
  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    address = [
      "45.159.48.76/24"
      "2403:71c0:2000:1253::a/64"
    ];
    routes = [
      {
        Destination = "0.0.0.0/0";
        Gateway = "45.159.48.1";
      }
      {
        Destination = "::/0";
        Gateway = "2403:71c0:2000::1";
        GatewayOnLink = true;
      }
    ];
  };
}
