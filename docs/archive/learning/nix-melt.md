# nix-melt 学习笔记

## 1. 是什么

`nix-melt` 是 `@figsoda` 用 Rust 写的 `flake.lock` 查看器，组织描述为
"A ranger-like flake.lock viewer"。它像 ranger 多列文件管理器一样展示
flake 依赖图，可以在不同 input 节点之间左右穿梭，并查看每个节点的
locked 元数据。

## 2. 用法

```bash
nix run github:nix-community/nix-melt
```

接受 `flake.lock` 路径或所在目录，默认读当前目录的 `flake.lock`；
`-t/--time-format` 控制 `lastModified` 时间戳的显示格式。

操作方式：

- `h` / `Left`：返回上一层 input；
- `l` / `Right`：进入当前选中的 input；
- `j` / `k` / `Up` / `Down`：在 input 列表间移动；
- `q` / `Ctrl-C`：退出。

## 3. flake.lock 数据模型

`flake.lock` 的核心是 `root` 加 `nodes` 两个字段：每个 node 有
`inputs`（名字到引用）和可选的 `locked` 信息。

引用有两种：

- `Direct(name)`：直接指向另一个 node；
- `Follow(path)`：从 root 开始沿路径逐级解析（空路径即 root 自身）。

`lock.rs` 里 `Lock::resolve()` 会把 root node 从 `nodes` 中移出，
`Resolve::get()` 再统一解析 Direct 和 Follow。serde 用 untagged enum
兼容 string/bool/int 类型的 input 值，`lastModified` 也按可选字段处理。

## 4. 代码结构

- `main.rs`：clap 解析参数、读文件、crossterm 事件循环；
- `state.rs`：持有 pane 栈和 ratatui Terminal，最多同时渲染左/中/右三列；
- `pane.rs`：用 ratatui `List` 渲染当前节点的 inputs 与 locked 字段；
- `lock.rs`：`flake.lock` 反序列化与引用解析；
- `build.rs`：设置 `GEN_ARTIFACTS` 时生成 man page 和全部 shell completion。

## 5. 工程细节

- Rust edition 2024，核心依赖是 ratatui + crossterm + clap + serde；
- `flake.nix` 用 `rustPlatform.buildRustPackage` + `cargoLock`，
  `checks = self.packages`，支持 Linux 的 aarch64/x86_64 与 macOS 的 aarch64；
- `ci.yml` 跨平台矩阵构建（macOS、Windows、Linux gnu/musl），并跑
  `clippy -D warnings` 与 nightly `fmt --check`；
- `release.yml` 打 tag 时构建 release 二进制并附带 man/completions；
- 最新一次 CI 运行（2026-08-04）为 success。

## 6. 对我们仓库的启发

- 我们的 `flake.lock` 有 30+ 输入，nix-melt 适合肉眼排查依赖和引用链，
  比看 `nix flake metadata` 更直观；
- 可以学它“build.rs 生成 man/completions + flake 里 installShellFiles
  安装”的产物交付方式；
- 作为一个很小的 ratatui 项目，它是了解 TUI 状态管理的好样例。

## 7. 参考

- [nix-melt](https://github.com/nix-community/nix-melt)
- [crates.io/nix-melt](https://crates.io/crates/nix-melt)
