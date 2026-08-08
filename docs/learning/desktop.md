# 桌面与日常使用层

## 仓库清单

- `home-manager`：声明式用户环境，支持 standalone / NixOS / nix-darwin；
- `nixvim`：用 Nix modules 配置 Neovim，生成 Lua；
- `stylix`：统一主题、壁纸、字体；
- `nixGL`：非 NixOS Linux 上包装 OpenGL/Vulkan 驱动；
- `nix-ld`：NixOS 上运行未 patch 的 Linux 动态链接二进制；
- `nix-direnv`：高性能 `use_nix` / `use_flake`。

## 适用边界

- Mac 开发机：`nix-direnv`、`home-manager`、`nixvim`；
- NixOS 服务器：`nix-ld`、`home-manager`；
- 非 NixOS Linux：`nixGL`、`home-manager` standalone；
- `nix-ld` 与 `nixGL` 在 Mac 上不适用。

## 与本地仓库的关系

`zhyi-packages/.envrc` 使用 `use flake`，依赖 nix-direnv；flake 里的
devshell/pre-commit/treefmt 构成开发体验。
