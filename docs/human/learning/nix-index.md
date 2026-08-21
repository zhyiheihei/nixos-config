# nix-index 与预生成数据库（学习笔记）

## 1. 是什么

`nix-index` 是 **nixpkgs 的文件数据库**（Rust，1339 star）。它索引
binary cache 里已构建 derivation 的文件清单，让你反查“哪个包提供
这个文件”：

```bash
nix-locate bin/hello
```

配套工具：

- `nix-index`：生成数据库；
- `nix-locate`：按文件名/路径查询；
- command-not-found 脚本：shell 里输入未安装命令时提示对应 attr。

`nix-index-database` 是 Mic92 维护的 **nix-index 数据库**仓库
（MIT，606 star，2026-08 仍在活跃）：每周为 nixos-unstable 生成
预构建的 nix-index 数据库，并提供 NixOS / nix-darwin / Home
Manager 模块，把 `nix-locate` 直接接上这份数据。

```sh
nix run github:nix-community/nix-index-database bin/cntr
```

## 2. 数据库格式

`src/frcode.rs` 实现类似 `locate` 的 frcode 编码，把海量重复路径
前缀压缩存储；`src/database.rs` / `files.rs` 负责高层读写；
`src/hydra.rs` 从 binary cache 下载 NAR 文件清单和引用；
`src/workset.rs` 用队列递归抓取。数据库生成通常要几分钟，默认从
cache.nixos.org 取数。

## 3. 使用

```bash
# 生成（约 5 分钟）
nix run github:nix-community/nix-index#nix-index

# 查询
nix run github:nix-community/nix-index#nix-locate -- bin/hello
```

如果不想自己生成，`nix-index-database` 提供预生成数据库和
NixOS/Home Manager module。

## 4. 数据库变体

- **Full（默认）**：全部文件索引，包名 `nix-index-with-db`；
- **Small**：只含 `/bin/` 下文件，更小更快，包名
  `nix-index-with-small-db`（comma 用它）。

要求 Nix >= 2.18（用 `unsafeDiscardReferences` 跳过 store 检查）。

## 5. 模块

- `nixosModules.default`：`programs.nix-index-database`，可选
  comma 包装（`programs.nix-index-database.comma.enable`）；
- `darwinModules.nix-index`：nix-darwin 同款；
- `homeModules.default`：Home Manager 版本，可接 shell 的
  `command-not-found`（`programs.nix-index.enable = true`）；
- 也提供 ad-hoc 下载脚本直接更新 `~/.cache/nix-index/files`。

## 6. 工程

- `generated.nix`：锁数据库 hash；`nix-index-wrapper.nix` /
  `comma-wrapper.nix`：包装器；
- CI（garnix）每周更新 + 发布；tests.nix 验证。

## 7. 对我们仓库的启发

- 我们可用它让 `nix-locate` / command-not-found 开箱即用（当前
  未接，可考虑加 `programs.nix-index-database`）；
- `comma` 依赖 nix-index 数据库实现“不安装直接运行”；
- 排查“哪个 nixpkgs 包提供某个二进制/库”时优先用 `nix-locate`；
- 服务器上没有 GUI，不适合常驻索引，但可以只在开发机/CI 里生成
  或使用预生成数据库；
- 它是“大数据产物 + 模块化消费”的典型：产物在 release，逻辑在
  flake，消费方只 import 模块。

## 8. 参考

- [nix-index](https://github.com/nix-community/nix-index)
- [nix-index-database](https://github.com/nix-community/nix-index-database)
