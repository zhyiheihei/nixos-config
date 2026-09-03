{
  pkgs,
  inputs,
  config,
  ...
}:
{
  sops.secrets.attic-upload-key.sopsFile = inputs.secrets + "/common/attic.yaml";

  systemd.services.attic-watch-store = {
    description = "Attic auto upload artifacts";
    wantedBy = [ "multi-user.target" ];

    path = [ pkgs.attic-client ];

    environment.HOME = "/var/cache/attic-watch-store";

    script = ''
      attic login --set-default zhyi https://attic.zhyi.xin $(cat ${config.sops.secrets.attic-upload-key.path})
      exec attic watch-store zhyi
    '';

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = "3";

      CacheDirectory = "attic-watch-store";
      WorkingDirectory = "/var/cache/attic-watch-store";
    };
  };
}
