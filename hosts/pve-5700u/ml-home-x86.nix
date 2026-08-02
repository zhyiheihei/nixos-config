{
  lib,
  LT,
  ...
}:
let
  activationMarker = "/nix/persistent/var/lib/ml-home-migration/pve-x86-ready";
  gatedServices = [
    "podman-archiveteam"
    "podman-clawemail"
    "podman-epic-awesome-gamer"
  ];
in
{
  imports = [
    # The application modules declare their normal vhosts, but the migration
    # backends bind directly to the home LAN and terminate TLS on ROCK 5C.
    ../../nixos/common-apps/nginx/vhost-options
    ../../nixos/optional-apps/archiveteam.nix
    ../../nixos/optional-apps/clawemail.nix
    ../../nixos/optional-apps/epic-awesome-gamer
  ];

  virtualisation.oci-containers.containers = {
    archiveteam.ports = lib.mkForce [
      "${LT.this.interconnect.IPv4}:${LT.portStr.ArchiveTeam}:8001"
    ];
    clawemail.ports = lib.mkForce [
      "${LT.this.interconnect.IPv4}:${LT.portStr.ClawEmail}:${LT.portStr.ClawEmail}"
    ];
  };

  systemd.services = lib.genAttrs gatedServices (_: {
    partOf = [ "ml-home-x86.target" ];
    unitConfig.ConditionPathExists = activationMarker;
  });
  systemd.targets.ml-home-x86 = {
    description = "Migrated ml-home-vm x86-only containers";
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
