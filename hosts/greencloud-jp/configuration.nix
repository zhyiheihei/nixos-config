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
  ];

  # 本机是机群的异地备份目标，不再向外推送自身备份。
  lantian.backup.schedule = null;

  # sftp-server.nix 默认 chroot 到 /nix/persistent/sftp-server（39G 系统盘），
  # 备份机改到 1T 数据盘 /data。
  # sshd 的 ChrootDirectory 要求整个路径 root 属主且不可被他人写，因此 home
  # 本身 root 属主、数据写到内部 sftp 可写的 backups/restic 子目录
  # （与 minimal-components/backup 的 restic root=/backups/restic 对齐）。
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

  # Gitea LFS/附件存储：原 router 上的 vaults3 已停摆（服务 inactive、数据盘
  # 缺失），改指向本机 vaults3（s3.zhyi.xin，nginx 443 TLS）。
  services.gitea.settings.storage = {
    MINIO_ENDPOINT = "s3.zhyi.xin:443";
    MINIO_BUCKET = "gitea";
    MINIO_LOCATION = "east-1";
    MINIO_USE_SSL = true;
    SERVE_DIRECT = false;
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

  lantian.nginxVhosts."s3.zhyi.xin" = {
    locations."/" = {
      proxyPass = "http://127.0.0.1:9000";
      proxyWebsockets = true;
      # S3 大对象上传不设上限；Host 默认透传 $host，SigV4 签名不受影响。
      extraConfig = ''
        client_max_body_size 0;
      '';
    };
    sslCertificate = "lets-encrypt-zhyi.xin";
    noIndex.enable = true;
  };

  # GreenCloud APAC 网络：DHCPv4 在该机房拿不到租约（2026-08-29 首启实测），
  # v4/v6 均为静态；v4 网关与 v6 网关（onlink 子网路由器）来自救援环境实测。
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
