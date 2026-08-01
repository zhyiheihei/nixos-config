{
  pkgs,
  lib,
  LT,
  ...
}:
{
  systemd.services.decluttarr = {
    wantedBy = [ "multi-user.target" ];
    after = [
      "radarr.service"
      "sonarr.service"
    ];
    requires = [
      "radarr.service"
      "sonarr.service"
    ];

    environment = {
      # Use environment variables instead of config file
      IS_IN_DOCKER = "1";

      REMOVE_TIMER = "10";
      REMOVE_FAILED = "True";
      REMOVE_STALLED = "True";
      REMOVE_METADATA_MISSING = "True";
      # May delete media that can be manually imported
      REMOVE_ORPHANS = "False";
      # May break multi season download
      REMOVE_UNMONITORED = "False";
      REMOVE_MISSING_FILES = "True";
      REMOVE_SLOW = "False";
      PERMITTED_ATTEMPTS = "3";
      RADARR_URL = "http://127.0.0.1:${LT.portStr.Radarr}";
      SONARR_URL = "http://127.0.0.1:${LT.portStr.Sonarr}";
    };

    preStart = ''
      for endpoint in \
        http://127.0.0.1:${LT.portStr.Radarr}/api/v3/system/status \
        http://127.0.0.1:${LT.portStr.Sonarr}/api/v3/system/status; do
        ready=false
        for _ in $(${lib.getExe' pkgs.coreutils "seq"} 1 60); do
          if ${lib.getExe pkgs.curl} \
            --silent --show-error --output /dev/null \
            --connect-timeout 1 "$endpoint"; then
            ready=true
            break
          fi
          ${lib.getExe' pkgs.coreutils "sleep"} 1
        done
        if [ "$ready" != true ]; then
          echo "Timed out waiting for $endpoint" >&2
          exit 1
        fi
      done
    '';

    script = ''
      export RADARR_KEY=$(cat /var/lib/radarr/config.xml  | grep -E -o "[0-9a-f]{32}")
      export SONARR_KEY=$(cat /var/lib/sonarr/config.xml  | grep -E -o "[0-9a-f]{32}")
      exec ${lib.getExe pkgs.nur-xddxdd.decluttarr}
    '';

    serviceConfig = LT.serviceHarden // {
      Restart = "always";
      RestartSec = "5";

      User = "zhyi";
      Group = "users";
    };
  };
}
