# fenix 学习笔记

## 1. 是什么

`fenix` 为 Nix 提供 Rust 工具链和 nightly rust-analyzer，目标是替代
`rustup` 和 `nixpkgs-mozilla` 的 rust overlay。

支持 `minimal`、`default`、`complete` profile，以及 `latest` nightly
toolchain。

## 2. 主要 API

- `toolchainOf`：按 channel/date/sha256 构造工具链；
- `fromToolchainFile` / `fromToolchainName`：从 `rust-toolchain.toml` 或
  工具链名构造；
- `withComponents`：只取 cargo/rustc/rustfmt/rust-src/clippy 等组件；
- `combine`：跨工具链组合组件；
- `stable` / `beta` / `minimal` / `default` / `complete` 等内置工具链。

## 3. 使用方式

- flake：`fenix.packages.<system>.minimal.toolchain`；
- overlay：`fenix.overlays.default`；
- 系统包：`(pkgs.fenix.complete.withComponents [ "cargo" "rustc" ... ])`。

## 4. 与 naersk/crate2nix 的关系

- `naersk` 默认使用 nixpkgs 的 rustc；
- `crate2nix` 可配合自定义工具链；
- `fenix` 负责“指定具体 Rust 工具链版本”，是更细粒度的一层。

## 5. 对我们仓库的启发

当前 `zhyi-packages` 的 Rust 需求只有 `zhconv-rs` maturin 绑定，直接用
`rustPlatform` 足够。如果以后需要固定 nightly 或具体 Rust 版本，
`fenix` 是首选。

## 6. 参考

- [fenix](https://github.com/nix-community/fenix)
