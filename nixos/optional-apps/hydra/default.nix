{
  LT,
  lib,
  pkgs,
  inputs,
  config,
  ...
}:
let
  py = pkgs.python3.withPackages (
    ps: with ps; [
      pydantic
      requests
    ]
  );
  path = lib.makeBinPath [
    pkgs.gitMinimal
    pkgs.jq
    pkgs.attic-client
  ];
  hydraGitSshCommand =
    "ssh -i ${config.sops.secrets.hydra-ssh-privkey.path} "
    + "-o IdentitiesOnly=yes "
    + "-o StrictHostKeyChecking=accept-new";
in
{
  imports = [
    ../nix-distributed.nix
    ../postgresql.nix
    ./cancel-old-builds.nix
    ./clear-build-failures.nix
    ./watchdog.nix
  ];

  sops.secrets.attic-upload-key = {
    sopsFile = inputs.secrets + "/common/attic.yaml";
    mode = "0444";
  };
  sops.secrets.hydra-ssh-privkey = {
    sopsFile = inputs.secrets + "/hydra.yaml";
    mode = "0440";
    owner = "root";
    group = "hydra";
  };

  lantian.nix-distributed.sshKeyPath = config.sops.secrets.hydra-ssh-privkey.path;

  # Force use original nix for Hydra hosts
  nix.package = lib.mkForce pkgs.nixVersions.latest;

  environment.etc."hydra/post-build".source = pkgs.writeShellScript "post-build" ''
    export PATH="${path}:$PATH"
    export HYDRA_URL="http://192.168.2.135:${LT.portStr.Hydra}"

    jq . "$HYDRA_JSON"
    exec ${lib.getExe' py "python3"} ${./post-build.py} "$HYDRA_JSON"
  '';

  # Hydra queue-runner still requires legacy ssh stores for remote builds.
  # Keep nix-distributed on ssh-ng for normal Nix, and translate only here.
  environment.etc."hydra/machines".text = lib.replaceStrings
    [ "ssh-ng://" ]
    [ "ssh://" ]
    config.environment.etc."nix/machines".text;

  services.hydra = {
    enable = true;
    # FIXME: disable failing checks
    package = pkgs.hydra.overrideAttrs (old: {
      doCheck = false;
    });
    hydraURL = "https://hydra.zhyi.cc:4000";
    listenHost = "192.168.2.135";
    notificationSender = "postmaster@zhyi.cc";
    port = LT.port.Hydra;
    buildMachinesFiles = [ "/etc/hydra/machines" ];
    useSubstitutes = true;

    maxServers = 10;
    maxSpareServers = 2;
    minSpareServers = 1;

    extraConfig = ''
      <runcommand>
        job = *:*:*
        command = /etc/hydra/post-build
      </runcommand>

      allow_import_from_derivation = true
    '';
  };

  # Disable SQLite VACUUM to avoid database lockup
  services.fast-nix-gc.noVacuum = true;

  systemd.services.hydra-notify = {
    environment.GIT_SSH_COMMAND = hydraGitSshCommand;
    preStart = ''
      if [ ! -f "$HOME/.config/attic/config.toml" ]; then
        ${lib.getExe pkgs.attic-client} login --set-default ${LT.nix.attic.cacheName} \
          https://attic.zhyi.cc:4000 \
          $(cat ${config.sops.secrets.attic-upload-key.path})
      fi
    '';
  };
  systemd.services.hydra-evaluator.environment.GIT_SSH_COMMAND = hydraGitSshCommand;
  systemd.services.hydra-queue-runner.environment.GIT_SSH_COMMAND = hydraGitSshCommand;

  systemd.services.hydra-attic-repush = {
    script = ''
      for F in /nix/var/nix/gcroots/hydra/*; do
        STORE_PATH="/nix/store/$(basename "$F")"
        ${lib.getExe pkgs.attic-client} push ${LT.nix.attic.cacheName} "$STORE_PATH" || true
      done
    '';
    serviceConfig = LT.serviceHarden // {
      Type = "oneshot";
      User = "hydra-queue-runner";
      Group = "hydra";
    };
  };

  systemd.timers.hydra-attic-repush = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "hourly";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
  };
}
