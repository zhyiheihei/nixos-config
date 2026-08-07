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
      # ml-builder additionally advertises aarch64-linux: it runs the author's
      # qemu-user-static-binfmt setup, so it can execute ARM derivations locally
      # in addition to its native x86_64 builds.
      [
        {
          # A builder advertises its native platform plus, for ml-builder, the
          # qemu-emulated aarch64 platform.
          systems = [ v.system ] ++ lib.optionals (n == "ml-builder") [ "aarch64-linux" ];
          hostName = "${n}.zhyi.cc";
          maxJobs = v.nixBuilder.maxJobs;
          protocol = "ssh-ng";
          speedFactor = v.cpuThreads;
          sshKey = cfg.sshKeyPath;
          sshUser = "nix-builder";
          supportedFeatures = v.nixBuilder.supportedFeatures;
          mandatoryFeatures = [ ];
        }
      ];

  # Follow the author: advertise the full extra-platforms list (which the
  # qemu-user-static-binfmt module populates with ARM platforms) so this
  # host can build ARM derivations locally through QEMU.
  localPlatforms = lib.uniqueStrings (
    [ pkgs.stdenv.hostPlatform.system ]
    ++ (config.nix.settings.extra-platforms or [ ])
  );
  localPlatformsString = builtins.concatStringsSep "," localPlatforms;
in
{
  options.lantian.nix-distributed = {
    sshKeyPath = lib.mkOption {
      type = lib.types.str;
      default = "/home/zhyi/.ssh/id_ed25519";
    };

    excludeHosts = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Builder host names that this dispatcher must not call.  This is used
        to keep the distributed-build graph acyclic while retaining the
        author's shared builder-discovery mechanism.
      '';
    };
  };

  config = {
    nix = {
      distributedBuilds = true;
      buildMachines =
        lib.flatten (
          lib.filter (v: v != null) (
            lib.mapAttrsToList mkBuildMachine (
              lib.filterAttrs (
                n: v:
                v.hasTag LT.tags.nix-builder
                && !(builtins.elem n cfg.excludeHosts)
              ) LT.otherHosts
            )
          )
        );
    };

    # Normal `nix build` already uses the local daemon directly. Advertising
    # localhost as an SSH builder makes the daemon recursively delegate a
    # derivation back to itself while holding its output lock. Hydra needs an
    # explicit local machine entry, so keep it only in Hydra's dedicated file,
    # matching the author's layout. Advertise big-parallel only where the host
    # opts in via nixBuilder.supportedFeatures (ml-builder yes, opi5p no).
    environment.etc."nix/machines-with-localhost".text =
      config.environment.etc."nix/machines".text
      + ''
        localhost ${localPlatformsString} - ${toString LT.this.nixBuilder.maxJobs} ${toString LT.this.cpuThreads} kvm,nixos-test,benchmark${lib.optionalString (builtins.elem "big-parallel" LT.this.nixBuilder.supportedFeatures) ",big-parallel"} - -
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
