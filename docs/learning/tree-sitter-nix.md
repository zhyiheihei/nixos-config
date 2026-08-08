# tree-sitter-nix 学习笔记

## 1. 是什么

`tree-sitter-nix` 是 Nix 语言的 [tree-sitter](https://tree-sitter.github.io/)
语法定义，作者 Charles Strahan，MIT 协议，当前版本 0.3.0，239 star。
tree-sitter 的增量解析能力是编辑器高亮、补全、代码导航的基础设施。

## 2. 仓库结构

- `grammar.js`：语法 DSL（预定义运算符优先级、externals、规则）；
- `src/`：生成产物 `parser.c`、`scanner.c`、`grammar.json`、
  `node-types.json`；
- `corpus/`：`tree-sitter test` 的语法快照测试；
- `queries/`：`highlights.scm`、`injections.scm`、`locals.scm`、
  `tags.scm`；
- `bindings/`：C/Go/Node/Python/Rust/Swift 绑定；
- `tree-sitter.json`：统一声明 grammar、绑定和元数据。

## 3. 语法设计

- 覆盖表达式、函数、formals、let/with/assert、attrset、字符串、
  path、URI、interpolation 等；
- 字符串片段和 path 片段放在 `externals`，由 C `scanner.c` 处理
  （tree-sitter 的经典做法，处理无法纯正则表达的部分）；
- `queries/highlights.scm` 用正则列出 builtins 和内置函数名做高亮；
- `injections.scm` 识别 `# bash` 注释、phase/hook 类 attr 和
  `writeShellScript`/`runCommand`，把对应字符串注入 bash 语法；
- `locals.scm` 故意留空：tree-sitter 的 scope 语义和 Nix 的惰性
  let 不匹配，避免高亮/跳转结果依赖定义顺序。

## 4. Nix 侧与 CI

- flake 用 `nix-github-actions` 从 `.#githubActions.matrix` 生成
  GitHub Actions 矩阵（Linux aarch64/x86_64、macOS intel/arm）；
- checks：build、editorconfig、`generated-diff`（重新 `npm run
  generate` 后 diff 已提交的 `src/`，防止生成产物过期）、treefmt、
  rust-bindings、node-bindings；
- `default.nix` 包装 nixpkgs 的 `tree-sitter-grammars.tree-sitter-nix`
  并启用 `tree-sitter test`；
- `publish.yml` 打 tag 后发布 Rust crate；
- mergify 自动 rebase 合并 Renovate 的依赖更新 PR。

## 5. 对我们仓库的启发

- 我们主要用 nixd 做 LSP，tree-sitter 语法是编辑器生态的另一条路线
  （nix-ts-mode、nixpkgs-lint 等工具都依赖它）；
- 值得借鉴“生成产物提交 + CI 里重新生成并 diff”的防漂移检查，
  我们文档里已有类似理念（如 gomod2nix 的 toml diff）；
- `locals.scm` 的取舍说明：工具实现不能盲目套用通用语义，要贴合
  Nix 惰性求值的实际行为。

## 6. 参考

- [tree-sitter-nix](https://github.com/nix-community/tree-sitter-nix)
- [tree-sitter](https://github.com/tree-sitter/tree-sitter)
- [nix-ts-mode](https://github.com/nix-community/nix-ts-mode)
