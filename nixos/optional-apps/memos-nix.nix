{
  LT,
  config,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./memos.nix ];

  config = {
    # Keep the podman unit defined for rollback, but never start it when the
    # native package backend is active.
    virtualisation.oci-containers.containers.memos.autoStart = lib.mkForce false;
    systemd.services.podman-memos.enable = lib.mkForce false;

    systemd.services.memos = {
      description = "Memos note-taking service";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        Environment = [ "TZ=${config.time.timeZone}" ];
        ExecStart = "${pkgs.memos}/bin/memos --addr 127.0.0.1 --port ${LT.portStr.Memos} --data ${config.lantian.memos.storage} --driver sqlite --instance-url https://memos.${config.networking.hostName}.zhyi.cc --log-level info";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
