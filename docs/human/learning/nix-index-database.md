# nix-index-database 学习笔记

## 1. 是什么

`nix-index-database` 是 Mic92 维护的 **nix-index 数据库**仓库
（MIT，606 star，2026-08 仍在活跃）：每周为 nixos-unstable 生成
预构建的 nix-index 数据库，并提供 NixOS / nix-darwin / Home
Manager 模块，把 `nix-locate` 直接接上这份数据。

```sh
nix run github:nix-community/nix-index-database bin/cntr
```

## 2. 数据库变体

- **Full（默认）**：全部文件索引，包名 `nix-index-with-db`；
- **Small**：只含 `/bin/` 下文件，更小更快，包名
  `nix-index-with-small-db`（comma 用它）。

要求 Nix >= 2.18（用 `unsafeDiscardReferences` 跳过 store 检查）。

## 3. 模块

- `nixosModules.default`：`programs.nix-index-database`，可选
  comma 包装（`programs.nix-index-database.comma.enable`）；
- `darwinModules.nix-index`：nix-darwin 同款；
- `homeModules.default`：Home Manager 版本，可接 shell 的
  `command-not-found`（`programs.nix-index.enable = true`）；
- 也提供 ad-hoc 下载脚本直接更新 `~/.cache/nix-index/files`。

## 4. 工程

- `generated.nix`：锁数据库 hash；`nix-index-wrapper.nix` /
  `comma-wrapper.nix`：包装器；
- CI（garnix）每周更新 + 发布；tests.nix 验证。

## 5. 对我们仓库的启发

- 我们可用它让 `nix-locate` / command-not-found 开箱即用（当前
  未接，可考虑加 `programs.nix-index-database`）；
- 它是“大数据产物 + 模块化消费”的典型：产物在 release，逻辑在
  flake，消费方只 import 模块。

## 6. 参考

- [nix-index-database](https://github.com/nix-community/nix-index-database)
