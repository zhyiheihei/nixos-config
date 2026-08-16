# docnix 学习笔记

## 1. 是什么

`docnix` 是 hsjobeki 做的“nix 生态全自动参考文档”实验：从源码
自动生成 `lib.*`、`pkgs.stdenv.*`、`builtins.*` 的文档，站点发布在
[nix-community.github.io/docnix](https://nix-community.github.io/docnix)。
25 star，无明确 license，README 明确标“Under Construction”，
2024-06 已归档。

依赖两条上游线：

- nixpkgs 注释要符合 RFC-145 文档注释格式（仓库里有
  [nixpkgs#262987](https://github.com/NixOS/nixpkgs/pull/262987) 草稿
  PR）；
- 一个加了 `unsafeGetAttrDoc` / `unsafeGetLambdaDoc` builtins 的
  Nix fork（`hsjobeki/nix` feat/doc-comments 分支）。

## 2. 四段流水线

0. **codemod（Rust）**：基于 rnix-parser 的 AST codemod，把 nixpkgs
   里旧式 `/* ... */` 注释自动迁移成 `/** markdown */` 格式
   （`# Example` / `# Type` 代码块、参数文档、重新缩进），产出
   `nixpkgs-migrated`（hsjobeki/nixpkgs 的 migrated 分支）；
1. **code-docs**：用 patched Nix 求值 `mkDocs.nix`，递归遍历
   `lib` / `pkgs` / `builtins`，对每个 lambda 调
   `unsafeGetLambdaDoc` / `unsafeGetAttrDoc` 取文档；带简单环检测
   （长度 ≤2）、跳过 `__` / `passthru`，并按“源码位置一致 →
   alias”、primop 按内容、部分应用按名字 三种规则补 alias，输出
   JSON；
2. **json-to-md（Node）**：把 JSON 转成带 yaml frontmatter 的
   markdown 页（导航/标签元数据），文档链接回 migrated nixpkgs
   源码位置；
3. **static-docs**：Astro + Starlight 静态站（用 dream2nix 打
   nodejs 包），内置 pagefind 搜索、sitemap，部署 GitHub Pages。

## 3. Flake 与工程

- 输入：nixpkgs / nixpkgs-migrated / nix(doc-comments) / nix-unit /
  dream2nix / crane / fenix；
- `codemod` 用 crane 构建，checks 含 clippy（`-D warnings`）、
  cargoDoc、cargoFmt、nextest；
- devShell 把 code-docs 的 JSON 和 markdown 拷进 static-docs 内容
  目录方便本地 `astro dev`；
- `deploy.yml`：`nix build .#static-docs`，拷 `result/.../public`
  到 `_site` 后走 GitHub Pages。

## 4. 对我们仓库的启发

- 我们已有 `docs/learning/` 和 nixdoc 学习笔记；docnix 是“注释即
  文档”的自动化尝试，Nix 生态最终选择了 nixdoc + RFC 0145 注释
  路线，与它一脉相承；
- codemod + 自定义 builtins 收集文档 + JSON 转 markdown 的管道，
  对“从源码自动生成参考手册”类任务有直接参考价值；
- 它因依赖未合并的 RFC/PR 而归档，说明这类“等上游”的实验仓库
  生命周期较短，学思路即可。

## 5. 参考

- [docnix](https://github.com/nix-community/docnix)
- [RFC 0145](https://github.com/NixOS/rfcs/blob/master/rfcs/0145-comments-as-documentation.md)
