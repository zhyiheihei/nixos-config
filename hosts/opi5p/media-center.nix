{
  config,
  lib,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  mediaGatedServices = [ ];
  gatedServices = mediaGatedServices;
  proxiedServices = [ ];
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
