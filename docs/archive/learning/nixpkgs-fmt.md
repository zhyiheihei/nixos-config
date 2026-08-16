# nixpkgs-fmt 学习笔记

## 1. 是什么

`nixpkgs-fmt` 是 zimbatm 写的 **Nix 代码格式化器**（Rust，
Apache-2.0，556 star，2024-07 已归档；README 写明已被
[nixfmt](https://github.com/NixOS/nixfmt) 取代）。目标：统一
nixpkgs 里的 Nix 代码风格，配合 pre-commit / ofborg。

## 2. 设计理念

与其他 pretty-printer 不同，nixpkgs-fmt 采用**保空白/注释的
AST 补丁**（基于 rnix-parser，已学）：

1. 最小化 merge conflict（贴近 nixpkgs 现有格式）；
2. 只展开不折叠（开发者决定单行/多行）；
3. 保留空行（表达分组）；
4. 每行缩进只变化一级；
5. 不对齐、不限行长、规则少。

好处：残缺/未完成的 Nix 也能格式化到出错处；输出依赖原始格式，
适合仓库规模化使用。

## 3. 功能

- CLI：`--check`、`--explain`、`--parse`（rnix/json 语法树）；
- 提供 wasm 网页 demo（可提交不满意的样例）；
- pre-commit hooks 配置；fuzz 测试。

## 4. 对我们仓库的启发

- 我们现在用 alejandra/nixfmt，不需要 nixpkgs-fmt；
- “格式化器应按仓库现有风格设计以最小化 diff”是规模化 CI 的
  关键取舍，后来被 nixfmt-rfc-style 继承；
- 它和 rnix-parser / nixd 一起构成 Nix 工具链谱系。

## 5. 参考

- [nixpkgs-fmt](https://github.com/nix-community/nixpkgs-fmt)
