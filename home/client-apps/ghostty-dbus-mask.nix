# 屏蔽 ghostty 包自带的 dbus service：其 SystemdService= 会映射到
# ghostty-service-wrapper 已 mask 的 app-*.service，单实例启动报
# "unit is masked"（上游 7027f0f2 漏了这环；若上游日后修复则本模块可删）。
{
  lib,
  pkgs,
  config,
  ...
}:
{
  home.packages = [
    (lib.hiPrio (
      pkgs.runCommand "ghostty-dbus-mask" { } ''
        if [ -f ${config.programs.ghostty.package}/share/dbus-1/services/com.mitchellh.ghostty.service ]; then
          mkdir -p $out/share/dbus-1/services
          ln -sf /dev/null $out/share/dbus-1/services/com.mitchellh.ghostty.service
        fi
      ''
    ))
  ];
}
