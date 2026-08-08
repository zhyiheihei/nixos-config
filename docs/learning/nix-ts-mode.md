# nix-ts-mode 学习笔记

## 1. 是什么

`nix-ts-mode` 是 Emacs 的 Nix 主模式，基于 Emacs 29+ 内置 tree-sitter
和 [tree-sitter-nix](./tree-sitter-nix.md) 语法。GPL-3.0，维护者
Remi Gelinas，76 star，版本 0.1.5，发布在 MELPA。

## 2. 功能

- 全语法高亮，`treesit-font-lock-level` 1-4 分档（essential →
  decorative）；
- 语义区分：变量 vs 属性、函数调用 vs 定义、参数、at-pattern；
- 缩进支持，`nix-ts-mode-indent-offset` 可调；
- 要求 Emacs 29.1+，30.x 有更多 font-lock face。

## 3. 实现

- `treesit-font-lock-rules` 按 feature 组织：bracket、comment、
  delimiter、keyword、string、operator、number、path、uri、
  parameter、variable 等；
- builtins/常量列表由 `nix eval` 生成，随语法库演进；
- 测试：ERT + `.erts` 缩进快照、font-lock face 断言；
- flake 导出 `supportedEmacsVersions`，devshell 带 cask 和
  pre-commit（nixpkgs-fmt/deadnix/statix）。

## 4. CI

- 可复用 workflow 在多个 Emacs 版本矩阵上跑 lint 和 ERT 测试；
- 按变更文件过滤（package/test/nix）只跑相关 job；
- 打 tag 用 release-changelog-builder 发版。

## 5. 对我们仓库的启发

- 我们不用 Emacs，但 nix-ts-mode 是编辑器侧 tree-sitter 的代表：
  [tree-sitter-nix](./tree-sitter-nix.md) 的 query 就在这里消费；
- “feature 分级 + 快照测试”的写法适合作为编辑器集成模块的参考。

## 6. 参考

- [nix-ts-mode](https://github.com/nix-community/nix-ts-mode)
- [tree-sitter-nix 学习笔记](./tree-sitter-nix.md)
