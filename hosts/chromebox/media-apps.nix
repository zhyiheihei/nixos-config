{
  lib,
  LT,
  ...
}:
{
  imports = [
    ../../nixos/optional-apps/archivebox.nix
    ../../nixos/optional-apps/handbrake-server.nix
    ../../nixos/optional-apps/immich.nix
    ../../nixos/optional-apps/kubo.nix
    ../../nixos/optional-apps/memos-nix.nix
    ../../nixos/optional-apps/metacubexd.nix
    ../../nixos/optional-apps/microsoft-rewards-script.nix
    ../../nixos/optional-apps/moviepilot.nix
    ../../nixos/optional-apps/tachidesk.nix
    ../../nixos/optional-apps/wallos.nix
  ];

  lantian.archivebox.storage = "/mnt/storage/archivebox";

  lantian.memos.storage = "/nix/persistent/srv/memos";

  lantian.wallos = {
    enable = true;
    storage = "/nix/persistent/srv/wallos";
  };

  lantian.moviepilot.enable = true;

  lantian.immich.storage = "/mnt/storage/immich";

  lantian.harden.immich-server.passwd = true;

  users.users.immich.extraGroups = [
    "video"
    "render"
  ];

  systemd.services.immich-server.serviceConfig.BindPaths = [ "/mnt/storage/immich-import" ];

  systemd.tmpfiles.settings.immich-import."/mnt/storage/immich-import"."d" = {
    mode = "0775";
    user = "immich";
    group = "users";
  };

  # handbrake-server.nix 默认带 --gpus=all（NVENC 镜像）；本机没有 NVIDIA，去掉该参数走 CPU 编码。
  virtualisation.oci-containers.containers.handbrake.extraOptions = lib.mkForce [
    "--ipc=host"
  ];

  virtualisation.oci-containers.containers.moviepilot.image =
    lib.mkForce "docker.io/jxxghp/moviepilot-v3:latest";

  virtualisation.oci-containers.containers.moviepilot.environment.AUTO_UPDATE_RESOURCE = "true";

  virtualisation.oci-containers.containers.moviepilot.extraOptions = [
    "--add-host=jellyfin-api.chromebox.zhyi.xin:${LT.this.interconnect.IPv4}"
  ];

  systemd.services.podman-moviepilot.unitConfig.RequiresMountsFor = [ "/mnt/storage" ];

  # 公网名（非默认 LAN 可达）。
  lantian.nginxVhosts."jellyfin.zhyi.xin".accessibleBy = lib.mkForce "public";
  lantian.nginxVhosts."tachidesk.zhyi.xin".accessibleBy = lib.mkForce "public";
  lantian.nginxVhosts."immich.zhyi.xin".accessibleBy = lib.mkForce "public";

  systemd.tmpfiles.settings.media-apps = {
    "/nix/persistent/var/lib/media-apps"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };
  };

  # 本机 30d 里有过 3.1% 时间可用内存 <1GB 的记录；earlyoom 优先杀媒体转码类进程，
  # 避免内存耗尽时 OOM 直接打掉 jellyfin。
  services.earlyoom = {
    enable = true;
    extraArgs = [
      "--prefer"
      "(jellyfin-ffmpeg|jellyfin|ffmpeg|immich|python3?|ghb|kubo|ipfs)"
      "--avoid"
      "(nix-daemon|nix-store|sshd|systemd|nginx|bird|knotd|pdns|zerotier|mihomo|podman)"
    ];
  };
}
