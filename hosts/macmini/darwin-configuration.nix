{ config, pkgs, lib, ... }:

{
  # 系统级 nix-darwin 配置：nix-daemon、用户、SSH、基础工具、stylix。
  # 用户级（home-manager）配置在 flake-modules/darwin-configurations.nix 里注入。

  # 让 LT.this 能解析到 hosts."macmini"（helpers/default.nix 依赖 networking.hostName）。
  networking.hostName = "macmini";
  networking.computerName = "zhyi's Mac mini";

  # nix-darwin 的 stateVersion 是整数（当前 maxStateVersion = 7），
  # 与 NixOS 的字符串 stateVersion 不同。
  system.stateVersion = 7;

  # 基础系统工具。
  environment.systemPackages = [
    pkgs.git
    pkgs.vim
  ];

  # 启用 Apple 内置 OpenSSH 服务器（远程登录）。
  services.openssh.enable = true;

  # 用户 molishanguang：home 目录 /Users/molishanguang，shell 交给 home-manager 的 zsh 模块管理。
  # 注意：这台 Mac 的实际登录用户是 molishanguang（非项目其他主机的 zhyi），
  # 沿用现有 macOS 用户，避免重建用户与迁移家目录。
  users.users.molishanguang = {
    name = "molishanguang";
    home = "/Users/molishanguang";
  };

  # stylix 系统级配置。darwin 侧 targets 只有 font-packages/jankyborders/neovim，
  # 不能照搬 NixOS 的 console/qt/kmscon；cursor 的 nur-xddxdd 包在 clean nixpkgs
  # 下不可用，故 darwin 侧不设 cursor（用 stylix 默认）。
  # 这里 enable = true 会触发 homeManagerIntegration 自动把 homeModules.stylix
  # 注入 home-manager，使 home/common-apps/stylix.nix 的 targets.opencode 选项可用。
  stylix = {
    enable = true;
    enableReleaseChecks = false;

    # followSystem 默认 true 会注入 copyModules，这些模块引用 osConfig；
    # 在 darwin 侧只提供 darwinConfig（不提供 osConfig），会导致求值失败。
    # 系统侧已在此显式配置 stylix，无需 followSystem 复制。
    homeManagerIntegration.followSystem = false;

    # 不用 image + matugen：matugen 的 flake 只暴露 linux systems，
    # darwin 侧无 package，求值会报 `attribute 'aarch64-darwin' missing`。
    # 显式设 base16Scheme 后其默认值（触发 matugen 的 generated.palette）
    # 不再被求值，generated.json 的 fileTree 条目也随之禁用。
    # 直接引用 stylix 自带的 tinted-schemes（flake=false）里的 base16 scheme。
    base16Scheme = "${config.stylix.inputs.tinted-schemes}/base16/catppuccin-mocha.yaml";

    fonts = {
      serif = {
        package = pkgs.nerd-fonts.noto;
        name = "Source Han Serif";
      };

      sansSerif = {
        package = pkgs.nerd-fonts.ubuntu;
        name = "Ubuntu";
      };

      monospace = {
        package = pkgs.nerd-fonts.ubuntu-mono;
        name = "Ubuntu Mono";
      };

      emoji = {
        package = pkgs.noto-fonts-emoji-blob-bin;
        name = "Blobmoji";
      };

      sizes = {
        applications = 10;
        desktop = 10;
        popups = 10;
        terminal = 12;
      };
    };
  };
}
