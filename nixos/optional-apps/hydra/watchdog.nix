{
  lib,
  LT,
  config,
  pkgs,
  ...
}:
let
  py = pkgs.python3.withPackages (ps: [ ps.requests ]);
  hydraBaseUrl = "http://${config.services.hydra.listenHost}:${LT.portStr.Hydra}";
in
{
  systemd.services.hydra-watchdog = {
    after = [ "network.target" ];
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.systemd ];

    environment = {
      HYDRA_QUEUE_URL = "${hydraBaseUrl}/queue";
      HYDRA_STATUS_URL = "${hydraBaseUrl}/status";
    };

    serviceConfig = LT.serviceHarden // {
      Type = "simple";
      ExecStart = "${lib.getExe' py "python3"} ${./watchdog.py}";
      Restart = "on-failure";
      RestartSec = "60";
    };
  };
}
