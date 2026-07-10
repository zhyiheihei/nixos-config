{
  lib,
  LT,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lantian.nix-distributed;

  mkBuildMachine =
    n: v:
    let
      isLocal = n == config.networking.hostName;
    in
    assert v.cpuThreads > 0;
    if isLocal then
      [ ]
    else
      # Hydra keys machines by store URI, so each host must have only one entry.
      [
        {
          inherit (v) system;
          hostName = "${n}.zhyi.cc";
          maxJobs =
            if cfg.maxJobsPerMachine == null then
              v.cpuThreads
            else
              lib.min cfg.maxJobsPerMachine v.cpuThreads;
          # Hydra's build-remote path currently only supports legacy SSH stores.
          protocol = "ssh";
          speedFactor = v.cpuThreads;
          sshKey = cfg.sshKeyPath;
          sshUser = "nix-builder";
          supportedFeatures = lib.optionals (v.cpuThreads >= 8) [ "big-parallel" ];
          mandatoryFeatures = lib.optionals (n == "ml-builder") [ "big-parallel" ];
        }
      ];

  platforms = builtins.concatStringsSep "," (
    lib.uniqueStrings (config.nix.settings.extra-platforms ++ [ pkgs.stdenv.hostPlatform.system ])
  );
in
{
  options.lantian.nix-distributed.sshKeyPath = lib.mkOption {
    type = lib.types.str;
    default = "/home/lantian/.ssh/id_ed25519";
  };
  options.lantian.nix-distributed.maxJobsPerMachine = lib.mkOption {
    type = lib.types.nullOr lib.types.ints.positive;
    default = null;
  };
  options.lantian.nix-distributed.localMaxJobs = lib.mkOption {
    type = lib.types.ints.positive;
    default = 2;
  };
  options.lantian.nix-distributed.localSupportedFeatures = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [
      "kvm"
      "nixos-test"
      "big-parallel"
      "benchmark"
    ];
  };

  config = {
    nix = {
      distributedBuilds = true;
      buildMachines =
        lib.flatten (
          lib.filter (v: v != null) (
            lib.mapAttrsToList mkBuildMachine (
              lib.filterAttrs (n: v: v.hasTag LT.tags.nix-builder) LT.otherHosts
            )
          )
        );
    };

    environment.etc."nix/machines-with-localhost".text = config.environment.etc."nix/machines".text + ''
      localhost ${platforms} - ${toString cfg.localMaxJobs} 1 ${builtins.concatStringsSep "," cfg.localSupportedFeatures} - -
    '';

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "nix-remote-build-off" ''
        sudo rm -f /etc/nix/machines
      '')
      (pkgs.writeShellScriptBin "nix-remote-build-on" ''
        sudo ln -s ${config.environment.etc."nix/machines".source} /etc/nix/machines
      '')
    ];
  };
}
