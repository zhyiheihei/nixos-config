{ lib, ... }:
let
  activationMarker = "/nix/persistent/var/lib/ml-home-migration/rock5c-edge-ready";
  gatedServices = [
    "fastapi-dls"
    "glauth"
    "podman-excalidraw"
    "uni-api"
    "vlmcsd"
  ];
in
{
  imports = [
    ../../nixos/optional-apps/excalidraw.nix
    ../../nixos/optional-apps/fastapi-dls.nix
    ../../nixos/optional-apps/glauth.nix
    ../../nixos/optional-apps/nginx-openspeedtest.nix
    ../../nixos/optional-apps/uni-api.nix
    ../../nixos/optional-apps/vlmcsd.nix
    ../../nixos/optional-apps/worker-vless2sub.nix

    ./app-edge.nix
    ./home-lan-edge.nix
    ./media-edge.nix
  ];

  systemd.services = lib.genAttrs gatedServices (_: {
    partOf = [ "ml-home-edge.target" ];
    unitConfig.ConditionPathExists = activationMarker;
  });
  systemd.targets.ml-home-edge = {
    description = "Migrated ml-home-vm edge and control services";
    wantedBy = [ "multi-user.target" ];
    unitConfig.ConditionPathExists = activationMarker;
    wants = map (name: "${name}.service") gatedServices;
  };

  systemd.tmpfiles.settings.ml-home-migration."/nix/persistent/var/lib/ml-home-migration".d = {
    mode = "0700";
    user = "root";
    group = "root";
  };
}
