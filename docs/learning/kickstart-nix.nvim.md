# kickstart-nix.nvim 学习笔记

## 1. 是什么

`kickstart-nix.nvim` 是一个“极简”的 Nix flake 模板，用来把 Neovim 配置
迁移到 Nix：插件和外部依赖由 Nix 管理，配置仍用 Lua 写。

## 2. 设计原则

- KISS，保持默认合理；
- 插件/语言服务器由 Nix 管理，不在插件里装；
- 配置只用 Lua，方便从非 Nix dotfiles 迁移；
- 使用 Neovim 内置 runtimepath/packadd 机制；
- 不用 Nix module DSL 抽象掉 Neovim 核心。

## 3. 目录结构

```text
flake.nix
nvim/       # 等价于 ~/.config/nvim
nix/        # mkNeovim.nix 与 overlay
```

## 4. 使用

- `nix run github:nix-community/kickstart-nix.nvim` 试跑；
- 插件加在 `nix/neovim-overlay.nix`；
- 配置放 `nvim/plugin/*.lua`；
- 可通过 `mkNeovim` 生成多个不同插件集合的 derivation。

## 5. 对我们仓库的启发

如果以后想用 Nix 管理 Neovim 但不想引入 `nixvim` 的重模块 DSL，
这个模板是更轻的中间路线。

## 6. 参考

- [kickstart-nix.nvim](https://github.com/nix-community/kickstart-nix.nvim)
