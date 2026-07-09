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
    pkgs.attic-client
    pkgs.gitMinimal
    pkgs.jq
  ];
  atticEndpoint = lib.removeSuffix "/${LT.nix.attic.cacheName}" LT.nix.attic.url;
  hydraPublicUrl = "https://hydra.zhyi.cc";
  hydraInternalUrl = "http://${LT.this.interconnect.IPv4}:${LT.portStr.Hydra}";
in
{
  sops.secrets.attic-upload-key = {
    sopsFile = inputs.secrets + "/common/attic.yaml";
    mode = "0444";
  };

  nix.package = lib.mkForce pkgs.nixVersions.latest;

  environment.etc."hydra/post-build".source = pkgs.writeShellScript "post-build" ''
    export PATH="${path}:$PATH"
    export HYDRA_URL="${hydraInternalUrl}"

    jq . "$HYDRA_JSON"
    exec ${lib.getExe' py "python3"} ${../../nixos/optional-apps/hydra/post-build.py} "$HYDRA_JSON"
  '';

  services.hydra = {
    enable = true;
    package = pkgs.hydra.overrideAttrs (_old: {
      doCheck = false;
    });
    hydraURL = hydraPublicUrl;
    listenHost = LT.this.interconnect.IPv4;
    notificationSender = "postmaster@zhyi.cc";
    port = LT.port.Hydra;
    buildMachinesFiles = [ "/etc/nix/machines-with-localhost" ];
    useSubstitutes = true;

    maxServers = 4;
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

  environment.etc."nix/machines-with-localhost".text = ''
    localhost ${pkgs.stdenv.hostPlatform.system} - 2 1 kvm,nixos-test,big-parallel,benchmark - -
  '';

  systemd.services.hydra-notify = {
    preStart = ''
      if [ ! -f "$HOME/.config/attic/config.toml" ]; then
        ${lib.getExe pkgs.attic-client} login --set-default ${LT.nix.attic.cacheName} \
          ${atticEndpoint} \
          $(cat ${config.sops.secrets.attic-upload-key.path})
      fi
    '';
  };

  systemd.services.hydra-watchdog = {
    after = [
      "network.target"
      "hydra-server.service"
    ];
    wantedBy = [ "multi-user.target" ];

    environment = {
      HYDRA_QUEUE_URL = "${hydraInternalUrl}/queue";
      HYDRA_STATUS_URL = "${hydraInternalUrl}/status";
    };

    path = [ pkgs.systemd ];

    serviceConfig = LT.serviceHarden // {
      Type = "simple";
      ExecStart = "${lib.getExe' py "python3"} ${../../nixos/optional-apps/hydra/watchdog.py}";
      Restart = "on-failure";
      RestartSec = "60";
    };
  };

  systemd.services.hydra-clear-build-failures = {
    path = [ config.services.postgresql.package ];
    script = ''
      echo "TRUNCATE hydra.public.failedpaths" | psql
    '';

    serviceConfig = LT.serviceHarden // {
      Type = "oneshot";
      User = "hydra";
      Group = "hydra";
    };
  };

  systemd.timers.hydra-clear-build-failures = {
    wantedBy = [ "timers.target" ];
    partOf = [ "hydra-clear-build-failures.service" ];
    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "12h";
      Unit = "hydra-clear-build-failures.service";
    };
  };

  systemd.services.hydra-attic-repush = {
    script = ''
      shopt -s nullglob
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

  networking.firewall.allowedTCPPorts = [ LT.port.Hydra ];

  environment.systemPackages = with pkgs; [
    attic-client
    hydra
  ];
}
