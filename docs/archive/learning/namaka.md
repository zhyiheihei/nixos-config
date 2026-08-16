# namaka 学习笔记

## 1. 是什么

`namaka` 是基于 [haumea](haumea.md) 的 Nix 快照测试工具，Rust CLI，
作者 figsoda，MPL-2.0，145 star，当前版本 0.2.1。思路借鉴 Rust 的
insta：不用手写期望值，先跑测试生成快照，再人工 review。

## 2. 用法

```bash
nix flake init -t github:nix-community/namaka
nix develop
namaka check   # 跑 nix flake check，为失败测试生成快照
namaka review  # 交互式接受/拒绝 pending 快照
namaka clean   # 清理未使用和 pending 快照
```

`--cmd` 可替换默认命令；`namaka.toml` 可配置 `dir`、
`[check].cmd`、`[eval].cmd`。

## 3. 测试组织

`nix/load.nix` 是 `haumea.load` 的包装：

```text
tests/
├─ foo/
│  ├─ expr.nix       # 被测表达式
└─ bar/
   ├─ expr.nix
   └─ format.nix     # 可选："json" / "pretty" / "string"
```

- 默认 `json`（`builtins.toJSON`），也可用
  `lib.generators.toPretty` 或按字符串原样保存；
- 快照存在 `tests/_snapshots/<name>`，文件头 `#json\n` 等标记格式；
- 所有测试通过时 `load` 返回 `{ }`，否则 throw 失败列表。

## 4. 工程

- flake 用 haumea 组织 `lib`，`checks = self.lib.load { src = ./tests; }`；
- Rust 包用 `rustPlatform.buildRustPackage`，`build.rs` 生成 man
  page 和 shell completions；
- 模板：default（Nix 库）、minimal（只用 nixpkgs.lib）、subflake；
- CI 的 `ci.yml` 直接 `nix run . check`（用 namaka 测 namaka），
  macos/ubuntu 矩阵 + Cachix；`release.yml` 打 tag 发 release。

## 5. 对我们仓库的启发

- 我们 `helpers/` 是 Nix 库，以后想加纯 Nix 函数测试时，namaka 比
  手写 `lib.debug.runTests` 更方便维护快照；
- “先失败生成快照，再 review 接受”的工作流适合重构时的行为回归。

## 6. 参考

- [namaka](https://github.com/nix-community/namaka)
- [haumea 学习笔记](haumea.md)
- [insta](https://github.com/mitsuhiko/insta)
