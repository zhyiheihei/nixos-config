{
  lib,
  pkgs,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-apps/ready";
  # 老的 *arr 四件套（sonarr/radarr/bazarr/prowlarr）及 decluttarr、exportarr
  # 已被 MoviePilot 链路完全替代，模块 import 于 2026-09-04 撤除（死链 vhost
  # 一并消失，homepage 同步不再列出）。回滚 = git revert 本提交重新加回
  # import；/nix/persistent/var/lib 下各服务数据未删。
  gatedServices = [
    "jellyfin"
    "podman-handbrake"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/jellyfin-rockchip.nix
    ../../nixos/optional-apps/handbrake-rockchip.nix
    ../../nixos/optional-apps/moviepilot.nix
    ../../nixos/optional-apps/chinesesubfinder.nix
  ];

  lantian.moviepilot.enable = true;
  lantian.chinesesubfinder.enable = true;

  # MoviePilot v3 (upgraded 2026-08-13): per the official wiki, v3 reuses the
  # v2 /config directory and SQLite DB, so volume/env mappings stay identical
  # and no data migration is needed (full backup taken before switching).
  # Overridden here at host level to keep the public optional-apps module
  # upstream-aligned.
  virtualisation.oci-containers.containers.moviepilot.image =
    lib.mkForce "docker.io/jxxghp/moviepilot-v3:latest";

  # v3's resource auto-update (curl_cffi download of user.sites.v3.bin /
  # sites.cpython-*.so) crashes the backend with SIGSEGV on this 8 GiB host
  # (2026-08-13, reproduced 3x at the same step even with memory headroom;
  # core dump then also fails to allocate). Resources are already at
  # v3.0.3/v3.0.0 on disk, so disabling updates loses nothing.
  virtualisation.oci-containers.containers.moviepilot.environment.AUTO_UPDATE_RESOURCE =
    "false";

  systemd.tmpfiles.settings.media-apps."/nix/persistent/var/lib/media-apps"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      unitConfig.ConditionPathExists = activationMarker;
    }))
    {
      # Never scan an empty local directory when the NAS mount is absent.
      podman-handbrake = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
      };
    }
  ];
}
