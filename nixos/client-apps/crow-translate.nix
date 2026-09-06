{
  pkgs,
  lib,
  config,
  ...
}:
let
  cfg = config.lantian.crow-translate;
in
{
  options.lantian.crow-translate = {
    enable = lib.mkEnableOption ''
      Crow Translate 划词翻译（Linux 下 Easydict 的替代，KDE 官方仓库维护）。
      Nixpkgs 的打包自带 KWayland 集成与 KDE 全局快捷键 desktop 动作
      （Ctrl+Alt+E 划词翻译、Ctrl+Alt+O 截图翻译等，经 D-Bus 触发，须由
      home 侧 autostart 让 crow 常驻后台）。
    '';
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [ crow-translate ];
  };
}
