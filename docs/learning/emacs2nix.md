# emacs2nix 学习笔记

## 1. 是什么

`emacs2nix` 是 Thomas Tuegel 写的 Haskell 工具：自动从
[ELPA](https://elpa.gnu.org/) / [MELPA](https://melpa.org/) 生成
Emacs 包的 Nix 表达式。29 star，GPL-3.0，2024-10 还有维护活动。

两个可执行文件：

- `elpa2nix`：拉 ELPA（含 nongnu）索引，生成
  `elpa-generated.nix`；
- `melpa2nix`：读 MELPA 仓库的 recipe，支持 git/hg/bzr/svn
  fetcher 和 stable/melpa-stable，生成 `melpa-generated.nix`。

## 2. 使用方式

```bash
git submodule update --init   # 需要 hnix
./elpa-packages.sh -o $NIXPKGS/pkgs/applications/editors/emacs-modes/elpa-generated.nix \
  --names names.nix
./melpa-packages.sh --melpa $MELPA -o .../melpa-generated.nix --names names.nix
```

每个 `*-packages.sh` 是 `nix-shell` wrapper，自动带上
`shell-fetch.nix` 的运行依赖。

## 3. 实现结构

- `src/Distribution/{Elpa,Melpa}.hs`：解析 ELPA archive / MELPA
  recipe；
- `src/Distribution/{Git,HG,Bzr,SVN}.hs`：不同 VCS 的 fetch 适配；
- `src/Distribution/Nix/*.hs`：把包信息转成 Nix AST
  （`Fetch`、`Hash`、`Index`、`Name`、`Package.Elpa` /
  `Package.Melpa`），最终用 **hnix** 库把 AST pretty-print 成
  `.nix` 文件；
- 两个主程序都用 `async` 并发抓取，`optparse-applicative` 做 CLI；
- `names.nix`：包名需要改 Nix 属性名时的映射表。

## 4. 构建与开发环境

- `package.yaml` → hpack 生成 `emacs2nix.cabal`，`package.nix`
  （Haskell mkDerivation）由 nixpkgs `callPackage` 使用；
- `default.nix` 用 `nixpkgs.lock.json` 钉住 nixpkgs，并过滤 src
  （只留 cabal/el/hs/LICENSE 等文件），还支持
  `default.overrides.nix` / `shell.overrides.nix` /
  `~/.config/nixpkgs/shell.overrides.nix` 分层覆盖；
- `hnix` 是 submodule（旧版 jwiegley/hnix），构建前必须 init。

## 5. 对我们仓库的启发

- 我们不维护 Emacs 包集，不引入；
- “Haskell 解析上游数据 → 构造 Nix AST → hnix 排版输出”比字符串
  拼 Nix 可靠得多，和 patsh（tree-sitter 精确修补）是同一思路：
  用结构化表示而不是文本拼接；
- “wrapper 脚本 + 固定 nixpkgs + 分层 overrides”的生成器开发
  环境值得 zhyi-packages 生成器参考。

## 6. 参考

- [emacs2nix](https://github.com/nix-community/emacs2nix)
