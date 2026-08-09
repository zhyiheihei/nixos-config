# nixos-cli-archive 学习笔记

## 1. 是什么

`nixos-cli-archive` 是“现代版 nixos-rebuild 替代品”的实验骨架
（Rust + clap），描述称 `nixos` 为 experimental。22 star，MIT，
2024-05 后停更并改名为 `-archive`：这个方向后来被我们已学的
[nixos-cli](https://github.com/nix-community/nixos-cli)（Go 版统一
CLI，393 star）接替。

## 2. 现状

仓库几乎是空壳：

- `src/main.rs`：只有 `clap::Parser` 的 `Cli {}`，没有任何子命令，
  `main` 只解析参数；
- `Cargo.toml`：唯一依赖 clap 4；
- `flake.nix`：crane 模板工程（buildPackage + devShell + checks），
  没有额外 buildInputs；
- 无测试、无文档，README 只有一句话。

## 3. 对我们仓库的启发

- 我们已有 nixos-cli（Go）的笔记，这个归档仓库不需要引入；
- 它体现了 nix-community 仓库的“命名空间沉淀”现象：实验失败/
  被取代的项目不删除，而是改名 `-archive` 保留上下文，避免和
  后续同名项目混淆；
- 从占位 CLI 到 Go 版 nixos-cli，说明这类“统一管理命令”项目
  需要重写迭代，仓库名不代表最终实现。

## 4. 参考

- [nixos-cli-archive](https://github.com/nix-community/nixos-cli-archive)
- [nixos-cli（Go 版，已学）](https://github.com/nix-community/nixos-cli)
