# rnix-parser 学习笔记

## 1. 是什么

`rnix-parser` 是 Nix 语言的 **Rust lossless parser**（477 star），
基于 matklad 的 rowan 语法树框架。特点：

- 保留所有 span 和空白信息；
- 打印 AST 能 100% 还原原文，即使输入是无效 Nix（错误节点会被
  标记）；
- 提供非递归树遍历，适合做编辑器、格式化器、重命名等工具。

## 2. 用途

- 交互式渲染/高亮 Nix AST；
- 格式化 Nix（nixpkgs-fmt 就是它的消费者）；
- 标识符重命名；
- 错误恢复解析（残缺表达式也能解析到出错处）。

## 3. 结构

- `src/parser.rs` / `tokenizer.rs`：词法和语法；
- `src/ast.rs` / `kinds.rs`：AST 类型定义；
- `examples/`：from-stdin、dump-ast、preserve、test-nixpkgs 等；
- `benches/all-packages.nix`：用整个 nixpkgs 表达式做 benchmark；
- `fuzz/`：cargo-fuzz 配置；
- `MIGRATING.md`：API 迁移说明。

## 4. 历史与状态

原作者 jD91mZM2 已离世，项目由社区继续维护；README 有一份
release checklist，强调 API 变化可以接受、行为变化要先讨论，并
用 nixpkgs-fmt 的测试套件防止回归。属于 Nix 工具链早期的重要
基础件；后续 nixd 等更重视语义，但 rnix 仍是很多编辑器工具的地基。

## 5. 对我们仓库的启发

- 我们不直接依赖 rnix-parser；
- 它和 tree-sitter-nix（增量语法）是两种互补路线：rnix 适合
  保真改写，tree-sitter 适合编辑器增量解析；
- 理解 lossless AST 才能理解 nixpkgs-fmt / nixd 为什么能保留
  注释和格式。

## 6. 参考

- [rnix-parser](https://github.com/nix-community/rnix-parser)
- [nixpkgs-fmt（已归档）](./nixpkgs-fmt.md)
- [tree-sitter-nix](./tree-sitter-nix.md)
