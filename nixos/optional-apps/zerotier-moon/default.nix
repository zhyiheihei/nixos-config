{
  lib,
  config,
  ...
}:
let
  moonFile = ./00000076d1b20a73.moon;
  cfg = config.lantian.zerotier-moon;
in
{
  options.lantian.zerotier-moon.enable = lib.mkEnableOption "zerotier moon";

  config = lib.mkIf cfg.enable {
    systemd.tmpfiles.settings."zerotier-moon" = {
      "/var/lib/zerotier-one/moons.d"."d" = {
        user = "zerotier-one";
        group = "zerotier-one";
        mode = "0755";
      };
      "/var/lib/zerotier-one/moons.d/00000076d1b20a73.moon"."L+" = {
        argument = "${moonFile}";
      };
    };

    systemd.services.zerotierone.restartTriggers = [ moonFile ];
  };
}
