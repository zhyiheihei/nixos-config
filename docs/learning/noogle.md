# noogle 学习笔记

## 1. 是什么

`noogle` 是 hsjobeki 维护的 **Nix API 搜索引擎**（[noogle.dev](https://noogle.dev)，
MIT，587 star，2026-08 仍在活跃）：按名称、英文描述和 **类型签名**
搜索 Nix / nixpkgs 函数，适合新手查函数用法。

## 2. 功能

- 渲染文档注释，支持按类型过滤（函数类型被解析解释）；
- 覆盖官方未文档化的 builtins（含 `builtins.derivation`），可
  通过 markdown 贡献扩展；
- 检测 lib / builtins 函数别名；用 `nixpkgs.lib` 里的别名文档覆盖
  builtins 文档，避免改 Nix 源码；
- 输出预渲染静态 HTML（利于搜索引擎），站内搜索用 pagefind，
  **Wasm 搜索**；
- nix / nixpkgs 每天更新。

## 3. 工程

- `pasta/`：Rust 索引模块（含 `src/eval.nix` 定义要索引的数据）；
- `salt/`：builtins 类型等补充数据；`nixPlugin/`：Nix 插件；
- `website/`：前端；`tests/`；flake 输出 `.#ui` 静态站；
- CI（main.yml）+ Mergify。

## 4. 对我们仓库的启发

- 我们查 Nix 函数主要靠 nixd / 手册，不需要引入；
- “从 nixpkgs 每天提取文档 + 类型签名 + 静态站”与 docnix
  （已学）同源但落地更成功；做 API 文档类工具可参考
  pasta/salt 的分工。

## 5. 参考

- [noogle](https://github.com/nix-community/noogle)
