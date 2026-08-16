# stylix 学习笔记

## 1. 是什么

`stylix` 是 **NixOS / Home Manager / nix-darwin / Nix-on-Droid 的
主题框架**（MIT，2360 star）。它从 Base16 色彩方案出发，自动把
配色、壁纸和字体应用到一大票应用，定位是“it just works”，而不只是
像 base16.nix / nix-colors 那样只生成色板。

## 2. 工作方式

- `stylix.base16Scheme` / `stylix.polarity` 定义配色，也可直接从
  Base16 schemes 输入选主题；
- `stylix.image` 设壁纸，`stylix.fonts` 设字体（含 serif / sans /
  monospace / emoji）；
- `modules/` 下每个应用一个目录：`<app>/hm.nix`（Home Manager）、
  `<app>/nixos.nix`（NixOS）、`<app>/meta.nix`（schema），支持
  alacritty、dunst、firefox、fcitx5、emacs、gtk/qt、konsole 等
  几十个应用；
- 生成的配置通常是模板（mustache）或应用自己的配置文件，挂到
  相应 Home Manager / NixOS 选项上。

## 3. 与 color scheme 工具的区别

- base16.nix / nix-colors：只把颜色暴露为变量，用户自己接入应用；
- stylix：还负责生成 wallpaper、fontconfig、GTK/Qt 主题、终端
  配色、浏览器样式等，用户只需开模块；
- 支持 darwin 和 Nix-on-Droid，跨系统复用同一套主题声明。

## 4. 工程组织

- flake 用 flake-parts + `nix-systems`，输入锁了大量 Base16 生态
  仓库（schemes、vim、kitty、tmux、zed、helix、firefox theme、
  GNOME Shell 等），保证主题来源可复现；
- `flake/ci.nix` / `testbeds.nix` 提供 `stylix#testbed:gnome:dark`
  这类可直接 `nix run` 的测试床；
- nix-community cachix 提供缓存。

## 5. 对我们仓库的启发

我们目前没有全局主题框架，桌面主题由 Home Manager 各自配置：

- 如果想让多台 client 视觉一致，stylix 是最省事的路线，但需要
  接受它对大量应用“自动接管”；
- 我们已有 fcitx5、firefox 等模块，可以只选 stylix 的局部应用
  模块，不必整套引入；
- 主题这类全局状态容易和用户手写 dconf/GTK 配置打架，接入前应
  先审计现有 Home Manager 模块。

## 6. 参考

- [stylix](https://github.com/nix-community/stylix)
- [stylix 文档](https://nix-community.github.io/stylix/)
