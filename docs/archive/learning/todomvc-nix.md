# todomvc-nix 学习笔记

## 1. 是什么

`todomvc-nix` 是一个教学型示例项目：用 Nix Flakes 组织一个完整的
TodoMVC 全栈应用，同时覆盖 Rust 和 Haskell 的前后端以及 PostgreSQL。
181 star，目标是让不同水平的 Nix 用户理解“真实项目怎么用 Nix 组织”。
Numtide 有对应的介绍文章。

## 2. 技术栈与结构

- 后端：Rust（sqlx + tide）和 Haskell（servant + polysemy）；
- 前端：Rust（Dominator + WASM，rollup/yarn）和 Haskell（Miso +
  jsaddle/ghcjs）；
- 数据库：PostgreSQL，用 sqitch 迁移；
- 根目录 `flake.nix` 导出 overlay、packages、devShell；
- `default.nix` / `shell.nix` 用 flake-compat 让非 flake 用户也能
  `nix-build` / `nix-shell`；
- `nix/` 目录按组件 `callPackage`：haskell、haskell-miso、
  rust-overlay、rust-frontend、database。

## 3. 关键实现

- overlay 里用 flake inputs 固定第三方依赖（polysemy、servant、
  miso 等），再 extend GHC 包集合，用 `callHackage` 覆盖版本；
- Rust 用 mozilla-overlay 的 `rustChannelOf` 锁定 stable 工具链，
  加 `wasm32-unknown-unknown` target；后端用 naersk 构建；
- 前端用 yarn2nix / `mkYarnPackage`；
- devshell 用 numtide devshell：`commands` 提供 `pginit` /
  `pgstart` / `pgstop` / `migrate` / `deletedb`，`env` 注入
  DATABASE_URL 等变量；
- database 组件把 sqitch 用 `symlinkJoin` + `makeWrapper` 包成
  `migrate` 命令，并自动带上 SQL 目录和 `sqitch.conf`。

## 4. CI

- `.github/workflows/nix-flake.yml`：ubuntu-latest 和
  ubuntu-24.04-arm 矩阵，用 DeterminateSystems nix-installer +
  magic-nix-cache；
- 跑 `nix flake check`、`nix develop --check` 和
  `nix develop --command echo`，验证 shell 可用。

## 5. 对我们仓库的启发

- 我们仓库的结构（flake + overlay + `helpers`/`pkgs` 分层）和它的
  “组件目录 + callPackage”思路一致；
- 它的 docs 按 `.nix` 文件逐块讲解，适合给新人做 Nix 教学参考；
- devshell 的“命令 + 环境变量 + 数据库脚本”模式可以借鉴，但我们
  日常用 home-manager + direnv，不需要照搬。

## 6. 参考

- [todomvc-nix](https://github.com/nix-community/todomvc-nix)
- [Numtide 介绍文章](https://numtide.com/articles/todomvc-nix-rejuvenation/)
