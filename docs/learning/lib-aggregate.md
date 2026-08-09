# lib-aggregate 学习笔记

## 1. 是什么

`lib-aggregate` 是 Artturin 维护的极简 flake：把“不依赖 nixpkgs
的纯 Nix 库”聚合到同一个 `lib` 命名空间下。13 star，无 license，
2026-08 仍在自动更新。仓库只有 flake.nix + CI。

```nix
outputs = inputs: {
  lib = inputs.nixpkgs-lib.lib
    // { flake-utils = inputs.flake-utils.lib; };
};
```

聚合对象：

- `nixpkgs-lib`：nix-community/nixpkgs.lib（已学，从 nixpkgs 抽出的
  纯 lib）；
- `flake-utils.lib`：numtide 的纯工具库。

## 2. CI：保证“不碰 nixpkgs”

- `update.yml`：每天 `nix flake update --commit-lock-file` 自动更新
  inputs 并直接提交；
- 更新后 `grep '"nixpkgs"' flake.lock --invert-match --quiet`
  **断言 lock 里没有任何 nixpkgs 依赖**——这是该聚合仓库的核心
  约束，防止纯 lib 被污染；
- dependabot 管 GitHub Actions。

## 3. 对我们仓库的启发

- 我们不依赖 nixpkgs 之外的纯 lib，不引入；
- “聚合层 + 自动更新 + lock 断言不引入某依赖”是维护“纯/受控
  依赖集”的好模式；我们在 zhyi-packages 或工具仓库想固定
  “零 nixpkgs 引用”时可直接照抄这个 CI 断言；
- 极简仓库的价值全在约束（CI 断言），代码本身几乎为零。

## 4. 参考

- [lib-aggregate](https://github.com/nix-community/lib-aggregate)
