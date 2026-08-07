{
  lib,
  LT,
  pkgs,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-apps/ready";
  proxy = "http://${LT.hosts.router.interconnect.IPv4}:${LT.portStr.V2Ray.HttpClient}";
  proxyBypass = "localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.cc,.zhyi.xin,.m-team.cc,.m-team.io,api.m-team.io";
  proxyEnvironment = {
    HTTP_PROXY = proxy;
    HTTPS_PROXY = proxy;
    NO_PROXY = proxyBypass;
    http_proxy = proxy;
    https_proxy = proxy;
    no_proxy = proxyBypass;
  };
  gatedServices = [
    "jellyfin"
    "sonarr"
    "radarr"
    "bazarr"
    "prowlarr"
    "decluttarr"
    "podman-handbrake"
    "prometheus-exportarr-sonarr-exporter"
    "prometheus-exportarr-radarr-exporter"
    "prometheus-exportarr-prowlarr-exporter"
    "prometheus-exportarr-bazarr-exporter"
  ];
  proxiedServices = [
    "sonarr"
    "radarr"
    "bazarr"
    "prowlarr"
    "podman-handbrake"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/sonarr/sonarr.nix
    ../../nixos/optional-apps/sonarr/radarr.nix
    ../../nixos/optional-apps/sonarr/bazarr.nix
    ../../nixos/optional-apps/sonarr/prowlarr.nix
    ../../nixos/optional-apps/sonarr/decluttarr.nix
    ../../nixos/optional-apps/jellyfin-rockchip.nix
    ../../nixos/optional-apps/handbrake-rockchip.nix
  ];

  systemd.tmpfiles.settings.media-apps."/nix/persistent/var/lib/media-apps"."d" = {
    mode = "0700";
    user = "root";
    group = "root";
  };

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      unitConfig.ConditionPathExists = activationMarker;
    }))
    (lib.genAttrs proxiedServices (_: {
      environment = proxyEnvironment;
    }))
    {
      # Never scan an empty local directory when the NAS mount is absent.
      sonarr = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
        serviceConfig.BindPaths = [
          "/mnt/storage/media-sonarr"
          "/mnt/storage/.downloads-qb-pt"
          "/mnt/storage/.downloads-qb"
        ];
      };
      radarr = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
        serviceConfig.BindPaths = [
          "/mnt/storage/media-radarr"
          "/mnt/storage/.downloads-qb-pt"
          "/mnt/storage/.downloads-qb"
        ];
      };
      bazarr = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
        path = [ pkgs.mediainfo ];
        serviceConfig.BindPaths = [
          "/mnt/storage/media-radarr"
          "/mnt/storage/media-sonarr"
        ];
      };
      podman-handbrake = {
        after = [ "mnt-storage.mount" ];
        requires = [ "mnt-storage.mount" ];
      };
    }
  ];
}
