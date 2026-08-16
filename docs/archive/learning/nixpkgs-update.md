# nixpkgs-update 学习笔记

## 1. 是什么

`nixpkgs-update` 是 **半自动更新 nixpkgs 包** 的工具，也是 GitHub
bot `@r-ryantm` 背后的代码（606 star）。输入包名、旧版本、新版本，
它会：

- 更新版本号和 fetcher hash；
- 运行基础质量检查；
- 生成 commit 和 PR；
- 报告 rebuild 影响面；
- 生成 CVE 安全报告（NVD，由 Serokell / NLNet NGI0 Discovery
  资助）。

## 2. 数据源

- Repology 的 nix_unstable 仓库版本数据；
- GitHub releases API；
- 包的 `passthru.updateScript`；
- 用于判断 staging / staging-next / master 的 nixpkgs 分支版本。

## 3. 质量检查

- 运行包内二进制，检查退出码和是否输出新版本号；
- 检查 outpath 里是否包含新版本；
- 给出目录树和磁盘占用；
- CVE 报告分三类：本次更新修复的、引入的、前后都存在的；
- rebuild 报告复用 OfBorg 的机制，能列精确 rebuild 数；
- 超过约 500 个包需要 rebuild 时，PR 自动打到 staging。

## 4. 实现

- 当前打包的是 **Haskell 实现**（Polysemy effect 栈、optparse、
  sqlite-simple），`app/Main.hs` 是 CLI；
- 仓库 `rust/` 下另有一套实验性 Rust 实现（Repology/GitHub 版本
  采集 + Diesel SQLite），目前不是 flake 默认包；
- flake 的 `pkgs/default.nix` 用 nixpkgs `haskellPackages` 构建，
  `nixpkgs-update.nix` 提供 shell 和文档（mmdoc）。

## 5. 对我们仓库的启发

- 我们维护 `zhyi-packages` 的 nvfetcher 更新流程，nixpkgs-update
  的“Repology + GitHub releases + updateScript”三源对比思路可以
  借鉴；
- 反哺 nixpkgs 阶段：用 nix-init 生成包、用 nixpkgs-update 验证
  更新，再开 PR；
- 它的 staging 分派规则提醒我们：大规模版本升级要分开走，不能
  直接推到主分支。

## 6. 参考

- [nixpkgs-update](https://github.com/nix-community/nixpkgs-update)
- [nixpkgs-update 文档](https://nix-community.github.io/nixpkgs-update/)
- [nix-init](../../human/learning/nix-init.md)
