# 写 Nix 的开发工具链

## 分层

- `rnix-parser`：Rust lossless Nix parser，保留原始 span 与空白；
- `tree-sitter-nix`：编辑器增量解析语法；
- `nixd`：Nix language server，支持 NixOS/home-manager/flake-parts option
  补全与跨文件跳转；
- `vscode-nix-ide`：VSCode 扩展，可接 `nil` 或 `nixd`；
- `nixdoc`：从 `/** */` 注释生成函数文档；
- `nixpkgs-fmt`：已归档的旧格式化器；当前常用 `nixfmt-rfc-style` /
  `nixfmt-rs`。

## 仓库里的实际组合

`nixos-config` 与 `zhyi-packages` 使用：

- `treefmt-nix`：统一 formatter；
- `nixfmt-rs`：Nix 格式化；
- `pre-commit-hooks.nix`：提交钩子；
- `devshell`：把 `commands` 暴露成 `nix run .#xxx`。

参考实现见 `flake-modules/lantian-treefmt.nix` 与
`flake-modules/lantian-pre-commit-hooks.nix`。
