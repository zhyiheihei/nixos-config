{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
let
  sublinkClashTemplate = pkgs.writeText "sublinkpro-clash.yaml" (builtins.readFile ./sublinkpro/clash.yaml);
in
{
  imports = [ ./sublinkpro ];

  config = {
    # Keep the podman unit defined for rollback, but never start it when the
    # native package backend is active.
    virtualisation.oci-containers.containers.sublinkpro.autoStart = lib.mkForce false;

    systemd.services.sublinkpro = {
      description = "SublinkPro subscription management panel";
      after = [
        "network-online.target"
        "sops-install-secrets.service"
      ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        WorkingDirectory = "/var/lib/sublinkpro";
        EnvironmentFile = [ config.sops.templates."sublinkpro-env".path ];
        Environment = [
          "SUBLINK_PORT=${LT.portStr.SublinkPro}"
          "SUBLINK_DB_PATH=/var/lib/sublinkpro/db"
          "SUBLINK_LOG_PATH=/var/lib/sublinkpro/logs"
          "SUBLINK_LOG_LEVEL=info"
          "SUBLINK_CAPTCHA_MODE=1"
          "SUBLINK_EXPIRE_DAYS=3650"
          "TZ=${config.time.timeZone}"
        ];
        ExecStart = "${inputs.zhyi-packages.packages.${pkgs.system}.sublinkpro}/bin/sublinkpro";
        Restart = "on-failure";
        RestartSec = "5s";
        MemoryMax = "1G";
        TasksMax = 512;
      };

      preStart = ''
        ${pkgs.coreutils}/bin/install -D -m 0644 ${sublinkClashTemplate} /var/lib/sublinkpro/template/clash.yaml
      '';
    };

    systemd.services.sublinkpro-seed = {
      after = lib.mkForce [
        "sublinkpro.service"
        "sops-install-secrets.service"
      ];
      requires = lib.mkForce [ "sublinkpro.service" ];
    };
  };
}
