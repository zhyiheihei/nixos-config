# nix-community.github.io 学习笔记

## 1. 是什么

`nix-community.github.io` 是组织 GitHub Pages 仓库（zowoq 维护，
0 star，无 license，2026-06 仍有更新）。`index.md` 只有一句
“This page is deployed.”；主要内容是 **home-manager 的跳转页**：

- `home-manager/index.html` / `*.xhtml`：把旧链接
  `nix-community.github.io/home-manager/...` 重定向到
  `nixos.github.io/home-manager/...`（保留路径）；
- 用 JS 替换 URL + noscript 里的静态链接兜底。

## 2. 对我们仓库的启发

- 我们不需要 org 页面，不引入；
- 它演示了“项目迁出组织后保留 URL 跳转”的低成本做法：纯静态
  HTML 重定向页就能避免旧链接失效；
- 类似的链接迁移模式也可用于我们 docs 里旧文档路径的兼容。

## 3. 参考

- [nix-community.github.io](https://github.com/nix-community/nix-community.github.io)
