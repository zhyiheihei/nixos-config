{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.lantian.harden = lib.mkOption {
    type = lib.types.attrsOf lib.types.bool;
    default = { };
  };

  config = {
    systemd.services = lib.mapAttrs (
      _: v:
      # mkIf 而不是 if/else {}：harden 为 false 时必须不产生 systemd.services
      # 定义，否则模块系统会留下一个没有 ExecStart 的空单元，activation 重启它
      # 时报 "has a bad unit file setting"（服务从 OAuth 前沿切走后会踩到）。
      lib.mkIf v {
        serviceConfig = {
          BindReadOnlyPaths = [
            "/etc/machine-id"
            "/etc/resolv.conf"
            "${config.security.pki.caBundle}:/etc/ssl/certs/ca-certificates.crt"
            "${config.environment.etc.hosts.source}:/etc/hosts"
            "${pkgs.tzdata}/share/zoneinfo/${config.time.timeZone}:/etc/localtime"
            "${pkgs.tzdata}/share/zoneinfo:/etc/zoneinfo"
          ];
        };
        confinement = {
          enable = true;
          fullUnit = true;
        };
      }
    ) config.lantian.harden;
  };
}
