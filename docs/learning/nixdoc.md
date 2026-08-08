# nixdoc 学习笔记

## 1. 是什么

`nixdoc` 是 Rust 写的文档生成器：从 Nix 库文件的注释生成 CommonMark
参考文档，nixpkgs 的 `lib` 函数参考就由它生成。GPLv3，作者 Vincent
Ambo，后续由 asymmetric、infinisil、hsjobeki 维护，当前版本约 3.1，
172 star。

## 2. 注释格式

支持两种：

- RFC-145 官方 doc-comment：`/** ... */`，内容按 CommonMark 写，
  支持 `# Example` / `# Type` / `# Arguments` 小节；
- legacy 格式：`/* ... */`，识别 `Type:` 和 `Example:` 行，以及
  lambda 参数前的逐行注释。

迁移指南在 `doc/migration.md`，新代码应使用 `/** */`。

## 3. 用法

```sh
nixdoc --file lib.nix --category "" --description "" --prefix "" --anchor-prefix "" > lib.md
```

常用选项：

- `--prefix` / `--anchor-prefix`：控制 attr path 前缀和 anchor 前缀；
- `--json-output`：输出 JSON；
- `--manifest`：进入 export 模式，一次处理多个文件并输出
  `export.json`。

manifest 支持 `flat` / `deep` / `file` 三种发现模式，`include` /
`exclude` 过滤，`groups` 分组；deep 模式必须配合 `include`。

## 4. 实现

- 用 [rnix-parser](./rnix-parser.md) 解析 Nix AST，再遍历 attrset /
  let 绑定收集带注释的函数；
- 注释文本做缩进处理和标题层级迁移（H1/H2 留给外层文档，注释内
  H1-H4 迁移到 H3-H6）；
- legacy 模式有独立的 “Type:/Example:” 伪解析器；
- flake 用 `rustPlatform.buildRustPackage`，`checks.nixpkgsDocs`
  会直接用它重新生成 nixpkgs lib 文档做验证，另跑 rustfmt/clippy。

## 5. CI

- `build.yml`：ubuntu/macos 矩阵，`nix flake check` + Cachix。

## 6. 对我们仓库的启发

- 我们 `helpers/` 是 Nix 库代码，如果以后想给内部函数做参考文档，
  nixdoc 可以直接用，注释规范就是 RFC-145 `/** */`；
- “用工具重新生成 nixpkgs 官方文档作为 CI 检查”是很好的回归验证
  思路。

## 7. 参考

- [nixdoc](https://github.com/nix-community/nixdoc)
- [RFC-145 doc-comments](https://github.com/NixOS/rfcs/blob/master/rfcs/0145-doc-strings.md)
