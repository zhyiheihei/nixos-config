# nix-ld-rs 学习笔记

## 1. 是什么

`nix-ld-rs` 是 [nix-ld](https://github.com/Mic92/nix-ld) 的 Rust 重写，
用于在 NixOS 上运行未 patch 的动态二进制。仓库已弃用：代码已合并回
nix-ld。MIT 协议，137 star。

## 2. 功能

作为 nix-ld 的 drop-in replacement，识别以下环境变量：

- `NIX_LD`、`NIX_LD_{system}`（例如 `NIX_LD_x86_64_linux`）；
- `NIX_LD_LIBRARY_PATH`、`NIX_LD_LIBRARY_PATH_{system}`；
- `NIX_LD_LOG`（error/warn/info/debug/trace）。

额外能力：在 x86_64-linux 和 aarch64-linux 上，`NIX_LD_LIBRARY_PATH`
不会泄漏给子进程（VSCode Server 等场景不再污染 shell 环境）。

## 3. 实现

- `#![no_std]` / `no_main` Rust：直接处理 ELF、auxv、栈迁移和环境变量
  编辑，然后用 `execve` 启动真实的 ld.so；
- 用 goblin 解析 ELF，`entry_trampoline` feature 在 ld.so 启动真实
  程序前把 `LD_LIBRARY_PATH` 还原；
- `package.nix` 安装 `libexec/nix-ld` 链接、`nix-support/ldpath`，
  并用 tmpfiles 创建 `/lib64/ld-linux-*.so` 指向 loader；
- NixOS 测试：`programs.nix-ld.enable` + patchelf 后的 hello，
  验证默认路径和未设置 `NIX_LD` 时的 fallback。

## 4. 工程与 CI

- 支持 i686/x86_64/aarch64-linux；flake checks 包含包、devShell、
  NixOS tests、clippy；
- 没有 GitHub Actions，依赖 nix-community 的 buildbot（mergify
  等 `buildbot/nix-eval`）；
- `just test` 在三个 target 上跑集成测试（需要 binfmt 模拟）。

## 5. 对我们仓库的启发

- 我们目前没有启用 `programs.nix-ld`；
- 以后若要在 NixOS 上跑未 patch 的闭源二进制，直接用 nix-ld 即可
  （本仓库代码已并入其中），不必再用这个独立仓库。

## 6. 参考

- [nix-ld-rs](https://github.com/nix-community/nix-ld-rs)
- [nix-ld](https://github.com/Mic92/nix-ld)
