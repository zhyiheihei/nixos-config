# nixpkgs-wayland 学习笔记

## 1. 是什么

`nixpkgs-wayland` 是一个自动更新的 Wayland/sway/wlroots 工具 overlay，
针对 `nixos-unstable` 预构建并推送到 Cachix。

## 2. 工作流

- `update`：升级 nixpkgs 和包版本，构建成功才 push；
- `advance`：只升级 nixpkgs，暴露上游变化导致的破坏；
- `build`：验证 `master` 当前状态可以构建。

这种“Update / Advance / Build”三阶段 CI 是自动 overlay 仓库的经典模型。

## 3. 使用方式

- flake 包集：`nix run "github:nix-community/nixpkgs-wayland#wev"`；
- overlay：`inputs.nixpkgs-wayland.overlay`；
- 二进制缓存：`nixpkgs-wayland.cachix.org`。

## 4. 对我们仓库的启发

`zhyi-packages` 的自动更新也是同一思路：`auto-update.yml` 每天拉新版本，
构建通过后提交。区别是我们没有独立的 `advance` 步骤来暴露 nixpkgs 升级
带来的破坏；如果以后想要更稳，可以借鉴它的三阶段工作流。

## 5. 参考

- [nixpkgs-wayland](https://github.com/nix-community/nixpkgs-wayland)
