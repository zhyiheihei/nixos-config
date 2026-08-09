# nixd 学习笔记

## 1. 是什么

`nixd` 是一个 **Nix language server**（C++，1454 star），直接链接
Nix 的 C++ 库，因此能做真正的 Nix 语义分析，而不只是语法高亮。
功能包括：

- Nixpkgs/NixOS/home-manager/flake-parts option 补全和跳转；
- 包名补全（惰性求值）；
- 跨文件分析：跳到 nixpkgs 源码里的定义；
- 与系统 Nix 共享 flake/file 求值缓存。

## 2. 架构

仓库是 monorepo：

- `libnixf/`：Nix 前端（词法/语法/语义），LSP 底层库；
- `libnixt/`：测试/工具辅助；
- `nixd/`：LSP server 本体。

构建用 Meson；flake 提供 package、devShell 和 formatter。

## 3. 功能亮点

- **Inlay hints**：在 `with pkgs; [ ... ]` 等位置显示包版本
  （`nixd` 会求值 `name.version`）；
- **Semantic tokens**：可选实验功能，区分 attrset 创建和 attrset
  选择；
- **Option 补全**：配置 `nixd.options` 后，编辑 NixOS / Home
  Manager 配置时能补全选项名；
- `NIXD_FLAGS` 环境变量可传启动参数。

## 4. 编辑器接入

- VSCode 用 nix-vscode-ide，`nix.serverPath = "nixd"`；
- 其他 LSP 客户端直接配 `nixd` 命令；
- 文档里有完整的编辑器 setup 和 configuration 说明。

## 5. 对我们仓库的启发

我们已经在用 `nixd`（`flake-modules/nixd.nix`），它是最贴合本仓库
的 LSP：

- 对 `flake.nix` / `hosts/` / `nixos/` / `home/` 的 option 体系
  支持最好；
- 配置 `nixosConfigurations.<host>.options` 表达式后，主机配置里
  的补全/诊断直接可用；
- 和 treefmt / pre-commit 一起构成我们的编辑-格式化-检查链路。

## 6. 参考

- [nixd](https://github.com/nix-community/nixd)
- [nixd 文档](https://nix-community.github.io/nixd/)
- [vscode-nix-ide](./vscode-nix-ide.md)
