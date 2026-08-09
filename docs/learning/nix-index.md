# nix-index 学习笔记

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

如果不想自己生成，[nix-index-database](./nix-index-database.md)
提供预生成数据库和 NixOS/Home Manager module。

## 4. 与我们仓库的关系

- `comma` 依赖 nix-index 数据库实现“不安装直接运行”；
- 我们排查“哪个 nixpkgs 包提供某个二进制/库”时优先用
  `nix-locate`；
- 服务器上没有 GUI，不适合常驻索引，但可以只在开发机/CI 里生成
  或使用预生成数据库。

## 5. 参考

- [nix-index](https://github.com/nix-community/nix-index)
- [nix-index-database](./nix-index-database.md)
