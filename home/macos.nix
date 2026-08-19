{ ... }:
{
  imports =
    let
      ls = dir: builtins.map (f: (dir + "/${f}")) (builtins.attrNames (builtins.readDir dir));
    in
    # 全部 common-apps 都是跨平台的（bash/editorconfig/htop/jq/ssh/stylix/tunings/xdg）。
    (ls ./common-apps)
    # client-apps 里只挑跨平台、不依赖 osConfig/LT/桌面环境的模块。
    # 排除：packages/dev-tools/ai-coding/firefox/autostart/mangohud/mpv/plasma/fcitx/
    #       ghostty/kitty/looking-glass/steam/xilinx/gtk-themes/force-x11/force-local-desktop-entries/
    #       ulauncher-extensions/conda/discord/thunderbird/mime-types/openscad/fonts/stylix(依赖 firefox)。
    ++ [
      ./client-apps/git.nix
      ./client-apps/hushlogin.nix
      ./client-apps/mercurial.nix
      ./client-apps/sops.nix
      ./client-apps/yt-dlp.nix
      ./client-apps/zsh.nix
    ];
}
