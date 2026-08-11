{
  LT,
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.lantian.filecodebox;
  backendPort =
    if cfg.backend == "nix"
    then "12345"
    else LT.portStr.FileCodeBox;
in
{
  options.lantian.filecodebox = {
    storage = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/filecodebox";
      description = "Storage path for FileCodeBox data";
    };
    backend = lib.mkOption {
      type = lib.types.enum [
        "podman"
        "nix"
      ];
      default = "podman";
      description = "Backend used to run FileCodeBox";
    };
  };

  config = {
    virtualisation.oci-containers.containers.filecodebox = lib.mkIf (cfg.backend == "podman") {
      image = "docker.io/lanol/filecodebox:beta";
      labels."io.containers.autoupdate" = "registry";
      ports = [ "127.0.0.1:${LT.portStr.FileCodeBox}:12345" ];
      volumes = [ "${config.lantian.filecodebox.storage}:/app/data" ];
      environment = {
        HOST = "0.0.0.0";
        PORT = "12345";
        WORKERS = "1";
        LOG_LEVEL = "info";
      };
    };

    systemd.services.filecodebox = lib.mkIf (cfg.backend == "nix") {
      description = "FileCodeBox anonymous file sharing server";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        Environment = [
          "FILECODEBOX_DATA_DIR=${config.lantian.filecodebox.storage}"
        ];
        ExecStart = "${inputs.zhyi-packages.packages.${pkgs.system}.filecodebox}/bin/filecodebox";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    systemd.tmpfiles.settings.filecodebox."${config.lantian.filecodebox.storage}"."d" = {
      mode = "0700";
      user = "root";
      group = "root";
    };

    lantian.nginxVhosts = {
      "filebox.zhyi.xin" = {
        locations."/" = {
          proxyPass = "http://127.0.0.1:${backendPort}";
        };
        sslCertificate = "lets-encrypt-zhyi.xin";
        noIndex.enable = true;
      };
      "filebox.localhost" = {
        listenHTTP.enable = true;
        listenHTTPS.enable = false;
        locations."/".proxyPass = "http://127.0.0.1:${backendPort}";
        accessibleBy = "localhost";
        noIndex.enable = true;
      };
    };
  };
}
