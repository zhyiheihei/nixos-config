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

    # Nextcloud（2026-09-04 自上游对齐启用）：数据库走 Oracle Autonomous
    # DB（模块内固定连接串），OIDC 登录走 volcengine 的 Dex（client 见
    # dex.nix，secret 见 common/dex.yaml 的 dex-nextcloud-secret）。
    ../../nixos/optional-apps/nextcloud.nix

    # Syncthing 同步节点（自 greencloud 撤销后迁入，2026-09）：本机常驻公网、
    # 1T 数据盘，作为机群的常在线异地同步节点，配合家庭 NAS（opi5p）实现
    # Obsidian 知识库多端同步。GUI 里的设备/共享文件夹仍需手动对接
    # （模块 overrideDevices/overrideFolders = false）。
    ../../nixos/optional-apps/syncthing

    # Attic 二进制缓存（自 greencloud 迁入，2026-09）。S3 后端用本机
    # VaultS3（s3.zhyi.xin，与 Gitea 同一实例；2026-09 初曾指向家中
    # vaults3.zhyi.xin:8443，跨境大对象上传会被中间链路切断，CI
    # push-cache 连锁失败，遂切回本机并新建数据库、弃用旧缓存）。
    # atticd 的 S3 凭据改用本机实例统一凭据（见下方
    # atticd-s3-credentials template），JWT 签名密钥仍来自
    # common/attic.yaml，现有上传 token 不受影响。
    ../../nixos/optional-apps/attic.nix
  ];

  # Syncthing 存储放 1T 数据盘；默认值 /nix/persistent/media 在 40G 系统盘
  # 上放不下同步数据。
  lantian.syncthing.storage = "/data/syncthing";

  # 私有知识库（Obsidian vault）固定目录，与 opi5p 上 Ignis 的 vault
  # （/mnt/storage/media/Notes）同名，方便在 Syncthing 中对接同一共享文件夹。
  systemd.tmpfiles.settings.syncthing."/data/syncthing/Notes"."d" = {
    mode = "755";
    user = "syncthing";
    group = "syncthing";
  };

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

  # atticd 的 S3 连接凭据：改用本机 VaultS3 的统一凭据（与 Gitea 同一套），
  # 不再用 common/attic.yaml 里指向家中实例的 AWS key。JWT 签名密钥继续由
  # 公共模块的 attic-credentials 提供，既有 attic token（CI 上传、fleet
  # 只读）不受影响。systemd 按顺序读多个 EnvironmentFile，同名变量后者
  # 覆盖前者：模板放在 attic-credentials 之后，AWS_* 以本模板为准。
  sops.templates.atticd-s3-credentials = {
    content = ''
      AWS_ACCESS_KEY_ID=zhyi
      AWS_SECRET_ACCESS_KEY=${config.sops.placeholder.default-pw}
    '';
    mode = "0400";
    owner = "atticd";
    group = "atticd";
  };

  systemd.services.atticd.serviceConfig.EnvironmentFile = lib.mkForce [
    config.sops.secrets.attic-credentials.path
    config.sops.templates.atticd-s3-credentials.path
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

  # atticd 的 nix-cache 桶不会由 VaultS3 自动创建；用幂等 oneshot 保证
  # 存在，atticd 排在其后再启动。
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
        if ! ${vaults3Pkg}/bin/vaults3-cli bucket info nix-cache >/dev/null 2>&1; then
          ${vaults3Pkg}/bin/vaults3-cli bucket create nix-cache
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
