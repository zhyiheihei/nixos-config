{
  lib,
  pkgs,
  self,
  config,
  ...
}:
let
  # 与 backup.nix 同款交叉编译 rustic（见该文件注释）
  rustic =
    if pkgs.stdenv.hostPlatform.isAarch64 then
      self.allSystems.x86_64-linux._module.args.pkgs.pkgsCross.aarch64-multiplatform.rustic.overrideAttrs
        (old: {
          requiredSystemFeatures = (old.requiredSystemFeatures or [ ]) ++ [ "aarch64-cross" ];
        })
    else
      pkgs.rustic;

  inherit (pkgs.callPackage ./common.nix { inherit config rustic; }) resticCommands maintenanceHosts;

  pruneScript = repo: ''
    echo "Pruning ${repo}"
    # Concurrent reads of one pack race on rustic_core's fixed cache temporary filename.
    rustic-${repo} --no-cache forget || HAS_ERROR=1
  '';
in
{
  systemd.services.backup-prune = lib.mkIf (lib.hasAttr config.networking.hostName maintenanceHosts) {
    serviceConfig = {
      Type = "oneshot";
      CPUQuota = "40%";
    };
    unitConfig.OnFailure = "notify-email@%n.service";

    path = [
      pkgs.openssh
    ]
    ++ resticCommands;

    script = ''
      HAS_ERROR=0
      ${lib.concatMapStringsSep "\n" pruneScript maintenanceHosts."${config.networking.hostName}"}
      exit $HAS_ERROR
    '';
  };

  systemd.timers.backup-prune = lib.mkIf (lib.hasAttr config.networking.hostName maintenanceHosts) {
    wantedBy = [ "timers.target" ];
    partOf = [ "backup-prune.service" ];
    timerConfig = {
      OnCalendar = "*-*-* 16:00:00";
      RandomizedDelaySec = "1h";
      Unit = "backup-prune.service";
    };
  };

}
