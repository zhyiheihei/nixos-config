{
  lib,
  LT,
  config,
  pkgs,
  ...
}:
let
  cfg = config.lantian.nix-distributed;

  armPlatforms = [
    "aarch64-linux"
    "armv5tel-linux"
    "armv6l-linux"
    "armv7a-linux"
    "armv7l-linux"
  ];

  isArmPlatform = platform: builtins.elem platform armPlatforms;

  mkBuildMachine =
    n: v:
    let
      isLocal = n == config.networking.hostName;
      isBigParallelBuilder = n == "ml-builder";
    in
    assert v.cpuThreads > 0;
    if isLocal then
      [ ]
    else
      # Hydra keys machines by store URI, so each host must have only one entry.
      [
        {
          # A builder advertises only its native platform. Cross derivations
          # produced by pkgsCross have the build machine's native system and
          # therefore go to ml-builder without pretending it can execute ARM
          # binaries through QEMU.
          systems = [ v.system ];
          hostName = "${n}.zhyi.cc";
          maxJobs = v.cpuThreads;
          # Hydra's build-remote path currently only supports legacy SSH stores.
          protocol = "ssh";
          speedFactor = v.cpuThreads;
          sshKey = cfg.sshKeyPath;
          sshUser = "nix-builder";
          supportedFeatures = lib.optionals isBigParallelBuilder [
            "aarch64-cross"
            "big-parallel"
          ];
          mandatoryFeatures = [ ];
        }
      ];

  localPlatforms = lib.uniqueStrings (
    [ pkgs.stdenv.hostPlatform.system ]
    ++ builtins.filter
      (platform: !isArmPlatform platform)
      (config.nix.settings.extra-platforms or [ ])
  );
  localPlatformsString = builtins.concatStringsSep "," localPlatforms;
in
{
  options.lantian.nix-distributed.sshKeyPath = lib.mkOption {
    type = lib.types.str;
    default = "/home/zhyi/.ssh/id_ed25519";
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

    # Normal `nix build` already uses the local daemon directly. Advertising
    # localhost as an SSH builder makes the daemon recursively delegate a
    # derivation back to itself while holding its output lock. Hydra needs an
    # explicit local machine entry, so keep it only in Hydra's dedicated file,
    # matching the author's layout.
    environment.etc."nix/machines-with-localhost".text =
      config.environment.etc."nix/machines".text
      + ''
        localhost ${localPlatformsString} - ${toString LT.this.cpuThreads} ${toString LT.this.cpuThreads} kvm,nixos-test,benchmark - -
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
