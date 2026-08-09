# nix-snippets 学习笔记

## 1. 是什么

`nix-snippets` 是“社区精选的 Nix 表达式语言小片段”集合，目标是像
Rust By Example 一样让新手快速建立对 Nix 语言的理解。CC0-1.0，
16 star，2021-11 已归档。灵感来自 nu_scripts、nix-cookbook、
learnxinyminutes 等。

## 2. 内容与运行方式

`basics/` 下每个主题一个 `.nix` 文件，整个文件求值成一个 list，
可以直接运行：

```sh
nix eval -f basics/strings.nix
```

示例覆盖：整数/浮点（`7 / 2` vs `7 / 2.0`）、布尔、注释、
字符串（双引号/多行/`''...''` 缩进字符串、拼接、`${}` 反引用）。

`scripts/run-all.nu` 用 nushell 遍历目录，对每个片段跑
`nix eval -f`，CI 在 PR 时执行 `scripts/ci/test.sh` 全量验证，
保证片段可求值。

## 3. 工程

- flake devShell：nushell + nixpkgs-fmt；
- `docs/CONTRIBUTING.md` 说明如何加片段；
- 纯内容仓库，无其它逻辑。

## 4. 对我们仓库的启发

- 我们已有大量 Nix 配置经验，不需要引入；
- “每个教学主题是一个可求值的 Nix 文件 + CI 跑一遍”是教 Nix 的
  好模式，以后若写 Nix 教程可直接借鉴（片段必须能执行，不靠
  阅读者脑补）；
- 它和 nix-replication-guide 类的文档互补：一个教语言，一个
  教复刻。

## 5. 参考

- [nix-snippets](https://github.com/nix-community/nix-snippets)
