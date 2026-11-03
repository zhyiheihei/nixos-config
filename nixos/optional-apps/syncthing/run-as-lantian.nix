{ lib, ... }: {
  imports = [ ./default.nix ];

  services.syncthing = {
    user = lib.mkForce "zhyi";
    group = lib.mkForce "zhyi";
  };
  lantian.syncthing.storage = "/home/zhyi";
  systemd.services.syncthing.serviceConfig = {
    ProtectHome = false;
    BindPaths = [ "/home/zhyi" ];
  };
}
