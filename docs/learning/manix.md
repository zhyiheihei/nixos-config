# manix 学习笔记

## 1. 是什么

`manix` 是快速的 Nix 文档搜索 CLI（Rust），fork 自 mlvzk/manix，
Apache-2.0，135 star，版本 0.8.0-dev。

## 2. 支持的数据源

- Nixpkgs Documentation（XML 函数文档）；
- Nixpkgs Comments（用 rnix 解析源码注释）；
- Nixpkgs Tree（`pkgs` / `pkgs.lib` 的 attr path）；
- NixOS Options、Nix-Darwin Options、Home-Manager Options。

## 3. 用法

```sh
manix mergeattr
manix --strict mergeattr
manix --update-cache mergeattr
```

- 默认前缀匹配，`--strict` 精确匹配，`--update-cache` 强制重建
  bincode 缓存；
- 可配合 rnix-lsp fork 做 hover/补全，或配合 fzf 做交互式搜索。

## 4. 实现

- `DocSource` trait（`all_keys` / `search` / `search_liberal` /
  `update`），`AggregateDocSource` 用 rayon 并行聚合；
- `Cache` trait 用 bincode 序列化到 XDG cache；
- 选项数据来自 `nix-build` 生成的 options JSON；Nixpkgs tree 用
  `nix-instantiate --eval --json` 生成 attr 树；
- 注释用 rnix 解析，XML 函数文档用 roxmltree 解析；
- flake 用 naersk 构建。

## 5. 对我们仓库的启发

- 我们在编辑 Nix 时主要用 nixd，manix 适合命令行快速查 NixOS
  option / nixpkgs 函数；
- “多数据源聚合 + 本地缓存 + 宽松/严格两种匹配”的设计可以直接
  用于自建文档检索工具。

## 6. 参考

- [manix](https://github.com/nix-community/manix)
- [nix-doc](https://github.com/lf-/nix-doc)
