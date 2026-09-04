# 从 opi5p 迁入的媒体下载服务（tachidesk/peerbanhelper/bitmagnet）。
{
  lib,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/media-automation/ready";
  gatedServices = [
    "peerbanhelper"
    "podman-tachidesk"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/peerbanhelper.nix
    ../../nixos/optional-apps/tachidesk.nix
    ../../nixos/optional-apps/bitmagnet.nix
  ];

  systemd.services = lib.mkMerge [
    (lib.genAttrs gatedServices (_: {
      partOf = [ "media-automation.target" ];
      unitConfig.ConditionPathExists = activationMarker;
    }))
    (lib.genAttrs
      [
        "bitmagnet-dht"
        "bitmagnet-http"
        "bitmagnet-queue"
      ]
      (_: {
        partOf = [ "media-automation.target" ];
        unitConfig.ConditionPathExists = activationMarker;
        environment = LT.proxyEnvironment;
      })
    )
  ];

  systemd.targets.media-automation = {
    description = "Dragon-Q8B media automation stack";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices;
    after = [ "network.target" ];
  };

  systemd.tmpfiles.settings.media-automation = {
    "/nix/persistent/var/lib/media-automation".d = {
      mode = "0700";
      user = "root";
      group = "root";
    };
    # postgres 数据目录 NOCOW（写入密集，与 opi5p 同款）。
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
