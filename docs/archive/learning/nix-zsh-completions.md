# nix-zsh-completions 学习笔记

## 1. 是什么

`nix-zsh-completions` 为 Nix、NixOS、NixOps 生态提供 zsh 补全。BSD-3
协议，2015 年创建，当前 281 star / 36 fork。仓库以 `_<cmd>` 形式维护
传统 `nix-*` / `nixos-*` 命令补全，并提供 oh-my-zsh、antigen、纯 zsh
三种加载方式。

## 2. 使用方式

- NixOS：README 称设置 `programs.zsh.enable = true` 会自动安装启用；
- oh-my-zsh：克隆到 `custom/plugins` 并加入 plugins 列表；可选
  `prompt_nix_shell_setup` 在 `nix-shell` 里给提示符加 `[nix-shell]`
  前缀；
- 纯 zsh：`source nix-zsh-completions.plugin.zsh`，把仓库目录加入
  `fpath` 后执行 `compinit`；
- 要求 zsh >= 5.2（5.0.8 及更早有已知问题）。

## 3. 实现要点

- 每个命令一个补全文件，用 `#compdef` 声明；
- `_nix-common-options` 集中共享 Nix 全局选项，供各命令复用；
- 用 `_arguments` 描述子命令、长短选项和参数类型，并针对
  `nix-env` / `nix-shell` 按已输入内容动态切换补全上下文
  （例如 `-p` 后补包名、`-A` 后补 attribute path）；
- `nix.plugin.zsh` 提供 precmd hook，根据 `IN_NIX_SHELL` /
  `IN_NIX_RUN` 环境变量给提示符加前缀；
- 纯 shell 脚本、零运行时依赖。

## 4. CI

- `test.yml`：PR 和 push 到 master 时，在 ubuntu/macos 矩阵上对
  `_*` 与 `*.zsh` 文件跑 `zsh -n` 语法检查。
- 仓库较老（最近 push 2025-12），覆盖传统 nix 命令；统一 `nix`
  命令的补全由 Nix 包自身提供。

## 5. 对我们仓库的启发

- 我们客户端 zsh 用 oh-my-zsh + `zsh-nix-shell`，补全主要靠 Nix 包
  自带，不一定需要引入；
- 如果想让传统 `nix-env` / `nix-shell` / `nixos-*` 命令补全更完整，
  可以在 home-manager 的 zsh `fpath` 或 oh-my-zsh plugins 里加这个仓库；
- 值得借鉴它的“集中共享选项 + 每命令独立 `_arguments`”组织方式和
  轻量 `zsh -n` 语法检查 CI。

## 6. 参考

- [nix-zsh-completions](https://github.com/nix-community/nix-zsh-completions)
- [zsh-completions howto](https://github.com/zsh-users/zsh-completions/blob/master/zsh-completions-howto.org)
