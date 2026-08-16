# nixpkgs-lint 学习笔记

## 1. 是什么

`nixpkgs-lint` 是 Rust 写的语义 linter，基于
[tree-sitter-nix](tree-sitter-nix.md)，目标是几秒内 lint 整个
nixpkgs，替代“shell 一行式 + 正则”的 treewide 改动方式。MIT 协议，
作者 Artturin，当前版本 0.3.0，175 star。

## 2. 检测规则

默认启用的 lint：

- `buildInputs` 里出现 cmake / makeWrapper / pkg-config / intltool /
  autoreconfHook → 提示移到 `nativeBuildInputs`；
- `*Flags` 是字符串而不是列表 → 提示转成列表；
- `lib.optional` 的参数是 list → 提示改用 `lib.optionals`；
- `src` 里出现 `pname` 变量 → 提示替换为字符串。

未完成 lint（`--include-unfinished-lints`）：

- `nativeBuildInputs` 里来自 stdenv 的冗余包（coreutils、findutils、
  diffutils、gnugrep、gnutar、gzip、gnumake 等）。

## 3. 实现

- 用 tree-sitter-nix 解析，查询是程序生成的 S-expression
  （`#eq?` / `#match?` predicate），匹配后遍历捕获节点拿精确 span；
- `QueryType` 分 List、BindingAStringInsteadOfList、
  ArgToOptionalAList、XInFormals，规则本身可序列化成 JSON；
- rayon 并行扫描文件，walkdir 递归，ariadne 输出带源码的错误；
- CLI 支持 `--format`、`--node-debug`、`--include-unfinished-lints`、
  `--running-in-nixpkgs-ci`；
- flake 用 naersk 构建，提供 overlay 和 flake-compat；devshell 带
  cargo / rustfmt / clippy。

## 4. CI

- `test.yml`：ubuntu / macos 矩阵上跑 `nix-build` 和 `nix build`；
- 仓库有 `assets/*.nix` 测试样本和 Rust 单测。

## 5. 对我们仓库的启发

- 我们目前用 nixd + nixpkgs-fmt；nixpkgs-lint 可作为补充，检查
  zhyi-packages 里的 `buildInputs` 是否放错层；
- “AST + 查询 + 精确 span”比正则可靠，适合做 treewide 改造；
- 规则数据驱动，新增 lint 只需写查询或少量 Rust 代码，易扩展。

## 6. 参考

- [nixpkgs-lint](https://github.com/nix-community/nixpkgs-lint)
- [tree-sitter-nix 学习笔记](tree-sitter-nix.md)
