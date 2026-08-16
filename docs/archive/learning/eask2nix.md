# eask2nix 学习笔记

## 1. 是什么

`eask2nix` 是 jcs090218 维护的工具：把 [Eask](https://emacs-eask.github.io/)
（Emacs Lisp 包配置）转换成 Nix 表达式。11 star，GPL-3.0，
JavaScript CLI + Emacs Lisp 核心，2026-07 仍在活跃。

```sh
cd your-elisp-project/
eask2nix generate    # 生成 default.nix
```

前置：emacs、eask、nix-hash。npm 安装或下载 `pkg` 打包的各平台
二进制。

## 2. 实现流程

- `cmds/generate.js`：Node（yargs）先检查 emacs / eask / nix-hash
  三个可执行文件，然后让 Emacs 跑 `lisp/generate.el`；
- `lisp/generate.el` 用 Eask 的 `core/package` API：
  1. 构建/找到包 artifact（tar/el 文件）；
  2. `nix-hash --flat --base32 --type sha256 <artifact>` 算 hash；
  3. 读 `templates/trivialBuild.nix`，替换
     `{ NAME }` / `{ VERSION }` / `{ SUMMARY }` /
     `{ WEBSITE_URL }` / `{ SHA256 }`，写回项目根的 `default.nix`。

模板用 nixpkgs `trivialBuild` + `fetchurl`；URL 留占位符需要用户
填。README 的 Todo 明确“处理依赖”和“生成可安装表达式”还没做。

## 3. 分发与 CI

- npm 发布 + `pkg` 编译成 linux/mac/windows（x64/arm64）二进制；
- `build.yml`：矩阵跑 `pkg package.json -t <node>-<target>`，把
  lisp/templates/COPYING/README 一起打进 dist 上传 artifact；
- `Easkfile` 自己也是 Eask 工程（dogfooding）。

## 4. 对我们仓库的启发

- 我们不用 Emacs/Eask，不引入；
- 它和 emacs2nix（已学）思路不同：不解析 ELPA/MELPA 索引，而是
  “用 Eask 自己构建 artifact 再 hash”，更贴近用户实际包内容；
- Node 壳 + Emacs Lisp 逻辑 + 模板替换，说明“调用生态原生工具
  拿产物”比重新实现打包逻辑更省心。

## 5. 参考

- [eask2nix](https://github.com/nix-community/eask2nix)
