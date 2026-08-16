# rnix-lsp 学习笔记

## 1. 是什么

`rnix-lsp` 是 aaronjanse 维护的 **Nix 语言服务器**（WIP，Rust，
MIT，710 star，2024-01 已归档），基于
[rnix-parser](https://github.com/nix-community/rnix-parser)（已学）。
原作者 jD91mZM2 已故，README 附 RIP 纪念。

## 2. 功能

- 语法检查诊断；
- 基础 completion / rename / goto definition；
- expand selection；
- 用 nixpkgs-fmt 格式化；
- beta 级质量，1.0 前不承诺 semver；macOS 不保证支持。

## 3. 工程

- crates.io 发布（rnix-lsp）；`nix-env -f` 或 flake 安装；
- `src/` + playground；CI 跑 test；pre-commit；
- 各编辑器集成：coc.nvim、LanguageClient、vim-lsp、doom/lsp-mode/
  eglot、kak-lsp、vscode-nix-ide。

## 4. 对我们仓库的启发

- 我们日常用 nixd（已学）做 Nix LSP，不引入；
- rnix-lsp 是“语法树驱动 LSP”的早期实践，后来被 rnix-parser /
  nixd 生态接替；
- 它说明语言工具链迭代快，学习时记谱系即可。

## 5. 参考

- [rnix-lsp](https://github.com/nix-community/rnix-lsp)
