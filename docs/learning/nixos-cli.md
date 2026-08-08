# nixos-cli 学习笔记

## 1. 是什么

`nixos-cli` 是 Go 写的统一 NixOS 管理工具，目标是替代分散的
`nixos-*` 脚本，提供一体的 TUI/CLI。

## 2. 功能

- 替代 `nixos-rebuild` 等常用 NixOS 工具；
- generation manager；
- option preview TUI；
- 内置配置与模块文档。

## 3. 包结构

- `nixos-cli`：wrapped 版本，PATH 里带 Nix 等运行时依赖；
- `nixos-cli-unwrapped`：纯二进制，重建成本更低；
- 还有 `-legacy` 变体兼容旧命令。

## 4. 测试与文档

- 使用 `pkgs.testers.runNixOSTest` 做 NixOS 集成测试；
- 文档用 mdbook 网站 + scdoc man pages；
- 有明确 AI 贡献政策：要能解释代码、要有验证，agent 自动提交会被拒绝。

## 5. 对我们仓库的启发

我们日常用 `make` + `colmena`，不需要迁移到 `nixos-cli`。它的价值是
“统一 CLI + TUI”的交互设计，以及 NixOS 集成测试的组织方式。

## 6. 参考

- [nixos-cli](https://github.com/nix-community/nixos-cli)
- [nixos-cli docs](https://nix-community.github.io/nixos-cli)
