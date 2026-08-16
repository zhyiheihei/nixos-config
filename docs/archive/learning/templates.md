# templates 学习笔记

## 1. 是什么

`nix-community/templates` 是社区维护的 flake 模板集合（从
NixOS/templates 迁移过来），基于 flake-utils，MIT 协议，149 star。
用法：

```sh
nix flake init -t github:nix-community/templates#<template>
```

## 2. 模板列表

当前 13 个：

- `c`、`empty`、`flutter`、`gleam`、`go`、`haskell`、`java`、
  `julia`、`nextjs`、`ocaml`、`python`、`rust`、`zig`。

根 `flake.nix` 用 `mkWelcomeText` 统一生成 welcomeText，包含模板名、
描述、自带工具和 direnv/license 提示。

## 3. 模板风格

- 都走 flake-utils `eachDefaultSystem`；
- 普遍提供 `devShells.default`（语言工具 + LSP）和
  `packages.default`；
- Rust 用 naersk + fenix；Go 用 `buildGoModule`；Python 用
  `buildPythonApplication`；Zig 用 `stdenv` + `zig.hook`；NextJS 用
  `buildNpmPackage` + pnpm；
- 部分模板偏旧（例如还用 `defaultPackage`、npmDepsHash 占位），
  新项目可以只作起点，再对照 nixpkgs 当前用法调整。

## 4. CI

- `check.yml` 跑 `check.sh`：遍历每个模板目录执行
  `nix flake check`，保证模板可求值。

## 5. 对我们仓库的启发

- zhyi-packages 新增语言项目时，可以先用对应模板起步，再改成我们
  nixpkgs 原生 + nvfetcher 的路线；
- 我们 [language-packaging.md](language-packaging.md) 的结论和
  模板里的工具选择基本一致（Go 用 buildGoModule、Python 用
  buildPythonApplication）；
- “每个子目录都能 `nix flake check`”的 CI 组织方式适合模板/多项目
  仓库。

## 6. 参考

- [templates](https://github.com/nix-community/templates)
- [flake-utils](https://github.com/numtide/flake-utils)
