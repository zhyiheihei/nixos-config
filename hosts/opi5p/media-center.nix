# OPI5P 媒体中心。上游 lt-home-vm 的下载链（qBittorrent/sonarr/flexget）
# 在本仓库演化为：qB 与 *arr 迁往 router/rock5c，由 MoviePilot v3 接管；
# tachidesk / peerbanhelper 已迁至 dragon-q8b（负载降压），本机只保留
# bitmagnet 的门控与代理出口，以及为 rock5c 准备的 NFS 库目录。
{
  config,
  lib,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  mediaGatedServices = [
    "bitmagnet-dht"
    "bitmagnet-http"
    "bitmagnet-queue"
  ];
  gatedServices = mediaGatedServices;
  proxiedServices = [
    "bitmagnet-dht"
    "bitmagnet-http"
    "bitmagnet-queue"
  ];
  proxyEnvironment = lib.getAttrs [
    "HTTP_PROXY"
    "HTTPS_PROXY"
    "NO_PROXY"
    "http_proxy"
    "https_proxy"
    "no_proxy"
  ] config.environment.variables;
in
{
  imports = [
    ../../nixos/optional-apps/bitmagnet.nix
  ];

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      partOf = [ "media-automation.target" ];
      unitConfig.ConditionPathExists = activationMarker;
    }))
    (lib.genAttrs proxiedServices (_: {
      environment = proxyEnvironment;
    }))
  ];

  systemd.targets.media-automation = {
    description = "OPI5P media automation stack";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices;
    after = [
      "mnt-storage.mount"
      "postgresql.service"
    ];
  };

  systemd.tmpfiles.settings."media-storage" = lib.mkMerge [
    {
      "/mnt/storage".d = {
        mode = "755";
        user = "root";
        group = "root";
      };
      "/mnt/storage/downloads".d = {
        mode = "755";
        user = "zhyi";
        group = "users";
      };
    }
    {
      # 库目录名沿用已退役的 sonarr/radarr：MoviePilot v3 与 Jellyfin 的媒体库
      # 扫描仍以这两个路径组织 union（见 rock5c/media-edge.nix），改名断库。
      "/mnt/storage/media-radarr".d = {
        mode = "755";
        user = "zhyi";
        group = "users";
      };
      "/mnt/storage/media-sonarr".d = {
        mode = "755";
        user = "zhyi";
        group = "users";
      };
    }
  ];

  systemd.tmpfiles.settings.media-automation = {
    "/nix/persistent/var/lib/media-automation".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    # Bitmagnet's 16 GiB PostgreSQL database is write-heavy.  Set NOCOW while
    # the directory is still empty, before PostgreSQL initializes it on NVMe.
    "/nix/persistent/var/lib/postgresql" = {
      d = {
        mode = "0700";
        user = "postgres";
        group = "postgres";
      };
      h.argument = "+C";
    };
  };

}
