# naersk 学习笔记

## 1. 是什么

`naersk` 是最简单的 **Rust 项目 Nix builder**（1003 star）。

```nix
naersk.buildPackage {
  src = ./.;
}
```

它在纯 Nix 里解析 `Cargo.lock`，下载依赖并按 cargo 构建，不使用
IFD，适合 Hydra/GitHub Actions 等受限环境。默认 release 构建，
输出可执行文件。

## 2. 关键设计

- 无代码生成：不需要提交 `Cargo.nix` 之类的中间文件；
- 沙箱友好：解析全在 Nix 求值里完成；
- 默认用 nixpkgs 的 rustc/cargo，忽略 `rust-toolchain`；传
  `cargo` / `rustc` 参数可覆盖为 fenix 或 nixpkgs-mozilla 工具链；
- `remapPathPrefix` 默认把 `/nix/store` 源码路径重映射到 `/sources`，
  减小 closure；
- 大量可调选项：`cargoBuildOptions`、`cargoTestCommands`、
  `cargoClippyOptions`、`doDoc` 等，都透传给 `mkDerivation`。

## 3. 与 crate2nix / fenix 的定位

- `crate2nix`：生成“一个 crate 一个 derivation”的精确增量模型，
  适合大型 workspace；
- `naersk`：一个 derivation 直接 cargo build，简单直接；
- `fenix`：只提供 Rust 工具链，不负责打包；
- 它们可以组合：fenix 提供 rustc/cargo，naersk 负责 build。

## 4. 对我们仓库的启发

我们的 `zhconv-rs` 走 `rustPlatform.cargoSetupHook` + maturin，
因为它是 PyO3 Python 包：

- 如果以后出现独立 Rust 二进制包，naersk 是首选（比 crate2nix
  维护成本低）；
- 需要自定义工具链时再接 fenix，不要默认引入；
- `overrideAttrs` 在 naersk 产物上不推荐，用 `override` /
  `overrideMain` 参数。

## 5. 参考

- [naersk](https://github.com/nix-community/naersk)
- [crate2nix](crate2nix.md)
- [fenix](fenix.md)
