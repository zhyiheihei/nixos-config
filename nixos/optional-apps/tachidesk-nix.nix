{
  config,
  inputs,
  lib,
  LT,
  pkgs,
  ...
}:
{
  imports = [ ./tachidesk.nix ];

  config = {
    virtualisation.oci-containers.containers.tachidesk.autoStart = lib.mkForce false;

    users.users.suwayomi = {
      isSystemUser = true;
      uid = 1000;
      group = "suwayomi";
    };
    users.groups.suwayomi.gid = 1000;

    systemd.services.tachidesk = {
      description = "Tachidesk manga server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "suwayomi";
        Group = "suwayomi";
        WorkingDirectory = "/var/lib/tachidesk";
        Environment = [
          "TZ=${config.time.timeZone}"
          "BIND_IP=127.0.0.1"
          "BIND_PORT=${LT.portStr.Tachidesk}"
          "DEBUG=false"
          "WEB_UI_CHANNEL=bundled"
          "AUTO_DOWNLOAD_CHAPTERS=true"
          "AUTO_DOWNLOAD_EXCLUDE_UNREAD=false"
          "AUTO_DOWNLOAD_NEW_CHAPTERS_LIMIT=0"
          "AUTO_DOWNLOAD_IGNORE_REUPLOADS=false"
          "MAX_SOURCES_IN_PARALLEL=20"
          "UPDATE_EXCLUDE_UNREAD=false"
          "UPDATE_EXCLUDE_STARTED=false"
          "UPDATE_EXCLUDE_COMPLETED=false"
          "UPDATE_INTERVAL=6"
          "UPDATE_MANGA_INFO=true"
          "EXTENSION_REPOS=${builtins.toJSON [ "https://raw.githubusercontent.com/keiyoushi/extensions/repo/index.min.json" ]}"
          "FLARESOLVERR_ENABLED=true"
          "FLARESOLVERR_URL=http://127.0.0.1:${LT.portStr.FlareSolverr}"
          "SOCKS_PROXY_ENABLED=false"
        ];
        ExecStart = "${inputs.zhyi-packages.packages.${pkgs.system}.tachidesk-server}/bin/tachidesk-server";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };
  };
}
