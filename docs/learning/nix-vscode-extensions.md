# nix-vscode-extensions 学习笔记

## 1. 是什么

`nix-vscode-extensions` 提供 VS Code Marketplace 和 Open VSX 上扩展的
Nix 表达式，GitHub Action 每天更新，覆盖比 nixpkgs 里那几百个扩展全得多。

## 2. 使用方式

- flake：`github:nix-community/nix-vscode-extensions`；
- overlay：`nix-vscode-extensions.overlays.default`；
- 通过 `pkgs.nix-vscode-extensions.vscode-marketplace.<id>` 等取扩展；
- 也可用 `vscode-with-extensions` 组合出带扩展的 VS Code/VSCodium。

## 3. 注意点

- 支持 `x86_64-linux`、`aarch64-linux`、`aarch64-darwin`；
- 部分扩展 unfree，需要 `allowUnfree`；
- 有版本优先级策略：pre-release > release、platform-specific > universal；
- 不要滥用它的 API crawler。

## 4. 对我们仓库的启发

我们目前不管理 VS Code 扩展；若以后需要，优先用这个 flake 或
`nix4vscode`，不要自己写扩展下载脚本。

## 5. 参考

- [nix-vscode-extensions](https://github.com/nix-community/nix-vscode-extensions)
