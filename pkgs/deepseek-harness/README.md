# deepseek-harness（临时预置，等待 nixpkgs 合并）

从 nixpkgs PR [NixOS/nixpkgs#553134](https://github.com/NixOS/nixpkgs/pull/553134)
（`deepseek-harness: init at 0.1.0-rc.6`，commit `refs/pull/553134/head`）原样拉取
的官方包定义，用于在 nixpkgs 合并前把本项目的 dsh 从 llm-agents.flake 迁移到
`pkgs.deepseek-harness`。

文件来源于 PR：

- `default.nix`：buildNpmPackage 定义（`node --expose-internals` wrapper，
  bash/pnpm_11/bubblewrap PATH 注入，use-nix-bash patch，PTY smoke test 等）；
  文件名按本仓惯例由 PR 的 `package.nix` 改名为 `default.nix`（供 callPackage 目录解析）
- `package-lock.json`：npm lockfile（npmDepsHash 与之配对）
- `remove-dev-dependencies.patch`：剔除 npm tarball 里残留的 dev workspace 包
- `use-nix-bash.patch`：agent 终端 shellPath 指到 Nix bash（无 /bin/bash）

唯一改动：`meta.maintainers` 由 `gestalt337` 改为空（PR 未合并，nixpkgs
maintainer-list 尚无此人，eval 会失败）；PR 合并进 unstable 后应恢复官方
maintainers 或直接整体删除本目录。

## 合并后的清理（todo）

1. `nix flake update nixpkgs`（含 PR #553134 的提交）
2. 删除本目录 `pkgs/deepseek-harness/` 与 `overlays/61-deepseek-harness.nix`
3. 引用处无需改动：`pkgs.deepseek-harness` 由 nixpkgs 提供
4. 可选：dsh-web 模块 systemd `path` 里的 `pkgs.pnpm`/`pkgs.bash` 在迁移后已冗余
   （包 wrapper 内置），合并清理时一并删除