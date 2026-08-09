# nix-straight.el 学习笔记

## 1. 是什么

`nix-straight.el` 是 vlaci 做的 [straight.el](https://github.com/raxod502/straight.el)
（Emacs 包管理器）低层 Nix 集成；nix-community 仓库是其 fork，
MIT，20 star，Nix 工程，2023-10 后基本停更。

核心思路：先让 Emacs 跑一遍你的 `init.el`，只“收集” 
`straight-use-package` 用到的包名；再把它们映射到 nixpkgs
`emacsPackages` 的 derivation；最后生成一个 `.emacs.d` 环境，把
Nix store 里的包 symlink 成 straight 的本地 repo，让 straight
“假装”自己装的包。

## 2. 两步 Emacs 钩子（setup.el）

- `nix-straight-get-used-packages`：`advice-add` 覆盖
  `straight-use-package`，只记录包名，加载 init.el 后把包名列表
  写成 JSON；
- `nix-straight-build-packages`：先设置
  `straight-default-files-directive`（排除 *.elc），再
  `advice-add :around` 覆盖 recipe：如果
  `straight--repos-dir` 里已有本地 repo 就用 `:local-repo`，
  否则当 built-in 包，然后 `straight-override-recipe` 再跑原函数，
  让 straight 从 Nix 提供的目录加载。

还带一个 nativeComp 兼容 advice（deny-list 处理）。

## 3. Nix 侧（default.nix / libstraight.nix）

`default.nix` 参数：`emacsPackages`、`emacs`、`emacsInitFile`、
`emacsArgs`、`emacsLoadFiles`、`abortOnNotFound`。导出：

- `packageJSON`：`emacs -q --batch --load=setup.el ...` 跑收集，
  输出包名 JSON；
- `packageList`：JSON 映射到 `epkgs` 的 derivation；找不到时
  `abortOnNotFound`（默认 abort）或跳过；
- `emacsEnv`：最终环境，内部 `install` 把每个包（含递归的
  `propagatedBuildInputs`）按 `share/emacs/*/*/<ename>*` 等路径
  模式 symlink 进 `$out/straight/repos/<name>`，再跑
  `nix-straight-build-packages`，失败时打印 `cli.doom.*.error`
  栈。

`straight/` 是打补丁（`nogit.patch`）的 straight.el 包：Nix store
只读，VCS 操作不可用，所以去掉 git 相关逻辑。

## 4. 已知限制（README 明说）

- 包名靠 `meta.homepage` + `ename` 猜，两者不一致会重复装；
- store symlink 导致所有 VCS 操作不可用，内容可能与 MELPA 装的不
  完全一致；
- recipe target 被忽略，无法区分“melpa 包还是用户 fork”。

## 5. 对我们仓库的启发

- 我们不用 Emacs/straight，不引入；它是 nix-doom-emacs（已学）的
  底层机制；
- “用 advice 覆盖包管理器入口做干跑收集 → JSON → Nix 映射 →
  运行时再用 advice 覆盖 recipe”是给包管理器做 Nix 后端的巧妙
  模式，写类似工具时可参考。

## 6. 参考

- [nix-straight.el](https://github.com/nix-community/nix-straight.el)
- [straight.el](https://github.com/raxod502/straight.el)
