{
  inputs,
  config,
  lib,
  pkgs,
  ...
}:
let

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

    ../../nixos/optional-apps/sftp-server.nix

    ../../nixos/optional-apps/gitea

    # ./nextcloud.nix

    ../../nixos/optional-apps/syncthing

    ../../nixos/optional-apps/attic.nix

    ../../nixos/optional-apps/loki.nix
  ];

  # 日志存储落数据盘：loki 模块固定用 /var/lib/loki，这里把该路径绑到数据盘
  fileSystems."/var/lib/loki" = {
    device = "/data/loki";
    fsType = "auto";
    options = [ "bind" ];
  };

  systemd.tmpfiles.settings.loki."/data/loki"."d" = {
    mode = "0700";
    user = "loki-collector";
    group = "loki";
  };

  systemd.services.loki.unitConfig.RequiresMountsFor = [ "/var/lib/loki" ];

  lantian.syncthing.storage = "/data/syncthing";

  systemd.tmpfiles.settings.syncthing."/data/syncthing/Notes"."d" = {
    mode = "755";
    user = "syncthing";
    group = "syncthing";
  };

  lantian.backup.schedule = null;

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

    "/data/sftp-server/backups/rustic-storagebox"."d" = {
      user = "sftp";
      group = "sftp";
      mode = "755";
    };
  };

  lantian.nginxVhosts."greencloud-jp.zhyi.xin".sslCertificate = "lets-encrypt-zhyi.xin";

  services.gitea.settings.storage = {
    MINIO_ENDPOINT = lib.mkForce "s3.zhyi.xin:443";
    MINIO_BUCKET = lib.mkForce "gitea";
    MINIO_LOCATION = lib.mkForce "east-1";
    MINIO_USE_SSL = lib.mkForce true;
    SERVE_DIRECT = lib.mkForce false;
  };

  services.gitea.repositoryRoot = "/data/gitea/repositories";

  # 仓库目录在数据盘，而 gitea 走 confinement chroot（RootDirectory=/run/confinement/%n）：
  # chroot 里只认得 BindPaths/BindReadOnlyPaths，ReadWritePaths 不会把宿主路径 bind 进去，
  # 否则 gitea 建 hooks 目录时 mkdir /data 直接 EROFS，ExecStartPre 失败导致 crash loop。
  systemd.services.gitea.serviceConfig.BindPaths = [ "/data/gitea/repositories" ];

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
    serviceConfig = {
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
  lantian.harden.vaults3 = {
    enable = true;
    enableConfinement = false;
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

  systemd.network.networks.eth0 = {
    matchConfig.Name = "eth0";
    address = [
      "45.159.48.76/24"
      "2403:71c0:2000:1253::a/64"
    ];

    networkConfig.IPv6AcceptRA = "no";
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
