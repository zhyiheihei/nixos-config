{
  config,
  LT,
  lib,
  pkgs,
  inputs,
  ...
}:
let
  cfg = config.lantian.moviepilotNix;
  mp = inputs.zhyi-packages.packages.${pkgs.system}.moviepilot;
  # Run the backend directly under systemd instead of `moviepilot start`:
  # the CLI waits on a 2s-per-request health probe that is too tight for
  # slow/emulated boards (RK3566 cold start exceeds it), so the frontend
  # never gets spawned there.  systemd manages both processes natively.
  backendWrapper = pkgs.writeShellScript "moviepilot-backend" ''
    # Reuse the runtime environment (node PATH + full PYTHONPATH) from the
    # package's own bin/moviepilot wrapper instead of rebuilding it here:
    # makePythonPath over the flake-exposed propagatedBuildInputs picks the
    # wrong outputs (e.g. pyopenssl-dev) and breaks imports.
    eval "$(sed -n '/^export \(PATH\|PYTHONPATH\)=/p' ${mp}/bin/moviepilot)"
    # v3 agent capabilities probe shutil.which("ffmpeg"); the docker image
    # ships it, the nix package does not.
    export PATH="${lib.makeBinPath [ pkgs.ffmpeg ]}:$PATH"
    # The package wrapper sets AUTO_UPDATE_RESOURCE=false too, but only
    # PATH/PYTHONPATH are extracted from it above; without this v3's
    # resource check tries to write the read-only store (app/application).
    export AUTO_UPDATE_RESOURCE=false
    export PYTHONUNBUFFERED=1
    export MOVIEPILOT_AUTO_UPDATE=false
    export CONFIG_DIR="${cfg.dataDir}"
    cd "${mp}/share/moviepilot"
    exec ${pkgs.python3Packages.python.interpreter} -m app.main
  '';
in
{
  options.lantian.moviepilotNix = {
    enable = lib.mkEnableOption "MoviePilot media automation (nix package)";

    dataDir = lib.mkOption {
      type = lib.types.str;
      default = "/nix/persistent/var/lib/moviepilot";
      description = "Host directory for MoviePilot configuration, SQLite data and logs";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "127.0.0.1";
      description = "Backend bind address";
    };

    port = lib.mkOption {
      type = lib.types.port;
      default = 3001;
      description = "Backend (FastAPI/uvicorn) port";
    };

    frontendPort = lib.mkOption {
      type = lib.types.port;
      default = 3000;
      description = "Frontend (node service.js) port";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.rules = [
      "d ${cfg.dataDir} 0750 zhyi users"
      # BindPaths mounts happen before ExecStartPre, so the source dir must
      # exist beforehand; seed the writable plugin copy from the store here
      # (C skips existing files, keeping user-installed plugins).
      "d ${cfg.dataDir}/plugins-store 0750 zhyi users"
      "C ${cfg.dataDir}/plugins-store - - - - ${mp}/share/moviepilot/app/plugins"
      # v3 hardcodes /config for the plugin/package repo (package.py);
      # alias it to the persistent data dir on (tmpfs) roots.
      "L /config - - - - ${cfg.dataDir}"
    ];

    systemd.services.moviepilot-backend = {
      description = "MoviePilot backend (nix package)";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      serviceConfig = {
        Type = "simple";
        User = "zhyi";
        Group = "users";
        Restart = "on-failure";
        RestartSec = "10";
        ExecStart = backendWrapper;
        # v3 installs every plugin into ROOT_PATH/app/plugins (read-only nix
        # store). Bind a writable persistent copy over it so plugin installs
        # and updates survive; the copy is seeded by tmpfiles above.
        BindPaths = [
          "${cfg.dataDir}/plugins-store:${mp}/share/moviepilot/app/plugins"
        ];
        Environment = [
          "HOST=${cfg.host}"
          "PORT=${toString cfg.port}"
        ];
      };
    };

    systemd.services.moviepilot-frontend = {
      description = "MoviePilot frontend (nix package, node service.js)";
      wantedBy = [ "multi-user.target" ];
      after = [ "moviepilot-backend.service" ];
      wants = [ "moviepilot-backend.service" ];
      serviceConfig = {
        Type = "simple";
        User = "zhyi";
        Group = "users";
        Restart = "on-failure";
        RestartSec = "15";
        WorkingDirectory = "${mp}/share/moviepilot/public";
        ExecStart = "${pkgs.nodejs}/bin/node ${mp}/share/moviepilot/public/service.js";
        Environment = [
          "PORT=${toString cfg.port}"
          "NGINX_PORT=${toString cfg.frontendPort}"
          "MOVIEPILOT_BACKEND_HOST=${cfg.host}"
        ];
      };
    };
  };
}
