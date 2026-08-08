# neovim-nightly-overlay 学习笔记

## 1. 是什么

`neovim-nightly-overlay` 提供每日更新的 Neovim nightly 构建，可当作
flake 包或 overlay 使用。

## 2. 使用方式

直接引用包：

```nix
programs.neovim.package =
  inputs.neovim-nightly-overlay.packages.${pkgs.system}.default;
```

或作为 overlay：

```nix
nixpkgs.overlays = [ inputs.neovim-nightly-overlay.overlays.default ];
```

## 3. 注意点

- flake 每天自动更新，但你的 `flake.lock` 要手动 `nix flake update`；
- 它覆盖 `treesitter`，可能遇到 hash mismatch；
- 可用 `--override-input neovim-src github:neovim/neovim?ref=pull/XXXX/head`
  测试 Neovim PR。

## 4. 对我们仓库的启发

我们目前没有用 nightly Neovim；若以后需要，优先用 flake 包而不是 overlay，
避免 treesitter override 影响其他包。

## 5. 参考

- [neovim-nightly-overlay](https://github.com/nix-community/neovim-nightly-overlay)
