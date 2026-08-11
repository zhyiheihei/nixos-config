{
  config,
  inputs,
  lib,
  pkgs,
  ...
}:
{
  imports = [ ./sun-panel.nix ];

  config = {
    # Keep the podman unit defined for rollback, but never start it when the
    # native package backend is active. The helper container stays unchanged.
    virtualisation.oci-containers.containers.sun-panel.autoStart = lib.mkForce false;
    systemd.services.podman-sun-panel.enable = lib.mkForce false;

    systemd.services.sun-panel = {
      description = "Sun-Panel navigation homepage";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      wantedBy = [ "multi-user.target" ];

      serviceConfig = {
        Type = "simple";
        User = "root";
        Group = "root";
        Environment = [
          "SUN_PANEL_DATA_DIR=${config.lantian.sunPanel.storage}"
        ];
        ExecStart = "${inputs.zhyi-packages.packages.${pkgs.system}.sun-panel}/bin/sun-panel";
        Restart = "on-failure";
        RestartSec = "5s";
      };
    };

    # The packaged binary reads conf/conf.ini in the data dir, which already
    # listens on the same 3002 port the container used.
    lantian.nginxVhosts."index.zhyi.xin".locations."/".proxyPass =
      lib.mkForce "http://127.0.0.1:3002";
    lantian.nginxVhosts."sun-panel.localhost".locations."/".proxyPass =
      lib.mkForce "http://127.0.0.1:3002";
  };
}
