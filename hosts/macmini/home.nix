{ pkgs, lib, ... }:
{
  imports = [ ../../home/macos.nix ];

  # ===== Homebrew CLI 收编到 nix：ripgrep / uv 由 nix 提供，替代 brew formula =====
  # pcre2 是 ripgrep 的依赖自动带上；这三个 formula 收编后从 brew 卸载（GUI cask
  # bitwarden/codex/siyuan nix 管不了，保留在 brew）。
  home.packages = with pkgs; [
    ripgrep
    uv
  ];

  # ===== macOS 特有：把原 ~/.zshrc 私有配置并进声明式 =====
  # home-manager 接管后 ~/.zshrc 由 programs.zsh 生成，原文件里的
  # Homebrew 镜像、Hermes PATH、Edge debug alias 用 initExtra 追回。
  programs.zsh.initExtra = lib.mkAfter ''
    # Homebrew USTC 镜像
    export HOMEBREW_BREW_GIT_REMOTE="https://mirrors.ustc.edu.cn/brew.git"
    export HOMEBREW_CORE_GIT_REMOTE="https://mirrors.ustc.edu.cn/homebrew-core.git"
    export HOMEBREW_API_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles/api"
    export HOMEBREW_BOTTLE_DOMAIN="https://mirrors.ustc.edu.cn/homebrew-bottles"
    [[ -f /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"

    # Hermes Agent
    export PATH="$HOME/.local/bin:$PATH"

    # Edge 调试模式
    alias edge-debug="/Applications/Microsoft\ Edge.app/Contents/MacOS/Microsoft\ Edge --remote-debugging-port=9222"
  '';

  # ===== 补回原 ~/.gitconfig 的代理（home-manager 接管后显式保留） =====
  programs.git.settings = {
    http.proxy = "http://192.168.0.1:1080";
    https.proxy = "http://192.168.0.1:1080";
  };
}
