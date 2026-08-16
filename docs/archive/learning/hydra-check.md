# hydra-check 学习笔记

## 1. 是什么

`hydra-check` 是 Rust 写的 CLI，用来查 hydra.nixos.org 上某个包在
指定 channel 的构建状态。v2 用 Rust 重写，MIT 协议，作者 Felix
Richter / Bryan Lai，当前版本 2.1.0，175 star。

## 2. 用法

```bash
hydra-check hello
hydra-check hello python --channel 19.03
hydra-check nixos.tests.installer.simpleUefiGrub --arch aarch64-linux
hydra-check --channel staging-next --eval
```

主要选项：

- `--arch`：指定架构，默认取当前系统；
- `--channel` / `--jobset`：channel 是 jobset 的别名
  （unstable、master、staging-next、24.05 等）；
- `--short`：只看最近一次构建；`--json` / `--url`：机器可读输出；
- `--eval`：查看某个 evaluation 的输入、变更和排队任务；
- `--tests` / `--releases`：查询 release 测试；
- `--shell-completion`：生成 shell 补全；
- `HYDRA_CHECK_HOST_URL`：指向自定义 Hydra 实例。

## 3. 实现

- 用 reqwest blocking + scraper 抓取并解析 Hydra 的 HTML 表格，
  自带 BeautifulSoup 风格的 `SoupFind` 小封装；
- `NixpkgsChannelVersion::stable()` 通过解析 nixos.org manual 的
  `data-nixpkgs-channels` 元数据推断当前 stable 版本（README 明说是
  “hack”）；
- jobset/channel 映射有完整启发式：NixOS 上用 nixos/unstable，其他
  系统用 nixpkgs/unstable，darwin 用 darwin jobset；
- 用 comfy-table 排版、yansi 做超链接、clap 生成补全；
- `build.rs` 校验 Cargo.toml 与 package.nix 版本一致，并给版本加
  git revision 后缀；`package.nix` 在 nixpkgs 的 hydra-check 之上
  做版本覆盖。

## 4. CI

- `test.yml`：ubuntu + macos（Intel/ARM）矩阵，跑 `nix-build`、
  `nix flake check`、`cargo clippy`、`cargo fmt --check` 和 cargo
  test（含被忽略的网络测试）；
- `release.yml`：release tag 与 `. #hydra-check.version` 一致性校验。

## 5. 对我们仓库的启发

- 升级 nixpkgs 前可以用它快速确认目标包在 unstable 是否绿，减少
  盲升；
- “抓 HTML + CSS selector + 结构化输出”适合没有稳定 API 的外部
  站点查询场景；
- 版本一致性在构建期强制（build.rs），防止 Cargo 与 Nix 包版本
  漂移，这个思路可以推广到我们的打包流程。

## 6. 参考

- [hydra-check](https://github.com/nix-community/hydra-check)
- [hydra.nixos.org](https://hydra.nixos.org)
