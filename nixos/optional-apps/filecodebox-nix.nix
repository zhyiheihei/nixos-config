{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./filecodebox.nix ];

  config = {
    # Keep the podman unit defined for rollback, but never start it when the
    # native package backend is active.
    virtualisation.oci-containers.containers.filecodebox.autoStart = lib.mkForce false;
    systemd.services.podman-filecodebox.enable = lib.mkForce false;

    systemd.services.filecodebox = {
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

    # The packaged binary always binds uvicorn port 12345, while the podman
    # module exposed that port through LT.portStr.FileCodeBox on the host.
    lantian.nginxVhosts."filebox.zhyi.xin".locations."/".proxyPass =
      lib.mkForce "http://127.0.0.1:12345";
    lantian.nginxVhosts."filebox.localhost".locations."/".proxyPass =
      lib.mkForce "http://127.0.0.1:12345";
  };
}
