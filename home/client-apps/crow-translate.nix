{
  lib,
  LT,
  osConfig,
  ...
}:
{
  # 划词翻译依赖 crow 常驻后台注册 D-Bus 服务（org.kde.CrowTranslate），
  # 否则 desktop 动作的全局快捷键无响应。沿用 autostart.nix 的托管模式。
  xdg.configFile = lib.mkIf osConfig.lantian.crow-translate.enable (LT.gui.autostart [ "crow" ]);

  # crow 默认 StartMinimized=false：登录自启会弹主窗口。仅首次预置为托盘
  # 启动，文件存在即跳过，之后以用户在 GUI 内的修改为准。
  home.activation.crow-translate-bootstrap = lib.mkIf osConfig.lantian.crow-translate.enable (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      conf="$HOME/.config/crow-translate/crow-translate.conf"
      if [ ! -f "$conf" ]; then
        mkdir -p "$(dirname "$conf")"
        printf '[General]\nStartMinimized=true\n' > "$conf"
      fi
    ''
  );
}
