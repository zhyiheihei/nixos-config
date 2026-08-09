# nix-direnv 学习笔记

## 1. 是什么

`nix-direnv` 是 direnv 内置 `use_nix` / `use_flake` 的**高性能替代
实现**（MIT，2752 star）。它不是 direnv 本体，只负责“进入目录时
加载 Nix 环境”。

核心特性：

- 首次求值后缓存 `nix-shell` / `devShell` 环境，后续进入目录明显
  更快；
- 把结果 symlink 进用户 `gcroots`，防止构建依赖被 GC 掉（离线时
  也不会突然失效）；
- 不需要 lorri 那样的常驻 daemon。

## 2. 使用

`.envrc` 里写：

```bash
use flake
```

或对非 flake 项目：

```bash
use nix
```

实现上 `use_flake` / `use nix` 最终都调用 `nix print-dev-env`，可以
把额外参数透传（例如 `use flake . --impure`）。也支持非默认文件名：
`use nix foo.nix`。

## 3. 安装方式

- NixOS：`programs.direnv.enable = true` 后
  `programs.direnv.nix-direnv.enable = true`；
- Home Manager：`programs.direnv.nix-direnv.enable = true`（推荐，
  但版本跟随 HM）；
- 手动：把 `direnvrc` 加进 `~/.config/direnv/direnvrc` 或 `nix
  profile install`；
- 仓库自带 flake template。

## 4. 设计取舍

相比 lorri：

- 更简单：没有 daemon、没有 socket；
- 按目录触发求值而不是常驻 watch；
- 代价是没有 lorri 的“持续监控 + 增量重算”，每次进入目录都要跑
  `print-dev-env`，但缓存让重复进入很快。

`nix_direnv_disallow_fallback` 等函数可以关闭“新 devShell 求值失败
时沿用旧缓存”的默认行为。

## 5. 对我们仓库的启发

我们的 `zhyi-packages/.envrc` 已经用 `use flake`，依赖的就是
nix-direnv 语义：

- devShell 的依赖必须放进 `gcroots`，否则重建成本高；
- 缓存和回退机制意味着 `.envrc` 改动后应 `direnv reload` 再验证，
  不能只看旧 shell；
- 保持“direnv 只做加载、Nix 负责求值”的边界，避免引入 lorri
  这类常驻组件。

## 6. 参考

- [nix-direnv](https://github.com/nix-community/nix-direnv)
- [lorri](./lorri.md)
