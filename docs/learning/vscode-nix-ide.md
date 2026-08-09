# vscode-nix-ide 学习笔记

## 1. 是什么

`vscode-nix-ide` 是 VSCode/VSCodium 的 **Nix 语言支持扩展**
（508 star）。开箱功能：

- Nix 语法高亮（含 Markdown 里的 Nix 代码块）；
- 用 `nix-instantiate` 做语法/lint 诊断；
- 通过 `nixfmt` 或自定义命令格式化；
- 条件表达式、let/with、rec 等 snippet；
- Path Intellisense 集成做路径补全。

## 2. LSP 接入

完整语义能力靠外接 Nix language server：

```json
{
  "nix.enableLanguageServer": true,
  "nix.serverPath": "nixd",
  "nix.serverSettings": {
    "nixd": {
      "options": {
        "nixos": {
          "expr": "(builtins.getFlake \"/abs/path/flake\").nixosConfigurations.<name>.options"
        }
      }
    }
  }
}
```

支持 `nil` 和 `nixd`，也允许传带参数的命令数组；启用 LSP 后，
`nix.formatterPath` 失效，改由 server 配置负责格式化。

## 3. 工程结构

- TypeScript 扩展（`src/extension.ts`、formatter/linter 拆分）；
- `nix.tmLanguage.json` 语法来自 wmertens 的 Sublime Nix grammar；
- `syntax-tests/` 有快照测试；
- 开发用 `bun` + biome + lefthook，shell.nix 提供 Nix 环境；
- CI 跑 VSCode extension tests。

## 4. 对我们仓库的启发

- 我们在本地编辑 Nix 时主要用 nixd；VSCode 用户可以直接用这个
  扩展把 nixd 接进来；
- `nix.serverSettings.nixd.options.nixos.expr` 指向我们的
  `nixosConfigurations.<host>.options`，主机配置补全和跳转就能
  工作；
- 它的“语法高亮开箱即用、语义靠 LSP 插件”的分层值得学习。

## 5. 参考

- [vscode-nix-ide](https://github.com/nix-community/vscode-nix-ide)
- [nixd](./nixd.md)
