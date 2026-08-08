# rustowl-flake 学习笔记

## 1. 是什么

`rustowl-flake` 是 mrcjkb 维护的 flake，打包
[rustowl](https://github.com/cordx56/rustowl)（Rust 所有权/生命周期
可视化工具）。33 star，MPL-2.0，2026 年仍在活跃维护。

rustowl 必须用仓库里 `rust-toolchain.toml` 指定的特定 nightly
工具链构建，所以本 flake 用 rust-overlay 动态装那个版本。

```sh
nix run github:nix-community/rustowl-flake#rustowl   # cargo-owlsp
```

## 2. 输出

- `packages.rustowl`：主程序，`mainProgram = cargo-owlsp`；
- `packages.rustowl-nvim`：同源仓库里的 Neovim 插件，用
  `vimUtils.buildVimPlugin` 直接打；
- `overlays.default`：`rust-overlay` + rustowl overlay 组合
  （`composeManyExtensions`）；
- devShell 挂 git-hooks（alejandra + editorconfig-checker）。

flake 还声明 `nix-community.cachix` substituter，节省构建。

## 3. package.nix 的关键点

- `rust-bin.fromRustupToolchainFile` 读 rustowl 源码里的
  `rust-toolchain.toml`，得到精确 nightly，再
  `makeRustPlatform`；
- `importCargoLock` 用仓库 Cargo.lock 做依赖；
- 环境变量 `RUSTOWL_TOOLCHAIN` / `RUSTOWL_SYSROOTS` /
  `RUSTUP_TOOLCHAIN` 指向该工具链，让 owlsp 能找到 sysroot；
- `preCheck` 删掉 `tests/algorithm.rs`（注释说该测试不纯）；
- `postInstall` 把 `rustowlc` 装进
  `$out/bin/sysroot/<channel>/bin/`；
- 依赖 openssl，Darwin 加 zlib。

## 4. CI

- `nix-build.yml`：ubuntu-24.04（x86_64-linux）和 macos-14
  （aarch64-darwin）矩阵跑 `nix flake check` + 构建两个包，用
  cachix 推 nix-community 缓存；
- `update-flake-lock.yml`：每晚 DeterminateSystems 开
  `chore: update flake.lock` PR，带 dependencies/automated 标签，
  `reitermarkus/automerge` 自动 squash 合并。

## 5. 对我们仓库的启发

- 我们不需要 rustowl，不引入；
- “应用 + 同仓库编辑器插件一起打包、用 rust-overlay 精确复刻
  nightly 工具链”是 Rust 生态打包标准模板；zhyi-packages 以后
  包需要特定 nightly 的 Rust 工具可直接照抄；
- nightly 依赖 + 自动锁更新 + 双平台构建 + 缓存，组合起来就是
  “上游不稳定也能长期维护”的 flake 姿势。

## 6. 参考

- [rustowl-flake](https://github.com/nix-community/rustowl-flake)
- [rustowl](https://github.com/cordx56/rustowl)
- [rust-overlay](https://github.com/oxalica/rust-overlay)
