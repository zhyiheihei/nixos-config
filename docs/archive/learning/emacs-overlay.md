# emacs-overlay 学习笔记

## 1. 是什么

`emacs-overlay` 是 adisbladis 维护的 **bleeding edge Emacs
overlay**（629 star，Nix，2026-08 仍在活跃）：每天提供
ELPA/MELPA 包集、EXWM 依赖，以及 `emacs-git` / `emacs-unstable`
（含 `-nox`、`-pgtk` 变体）等最新 Emacs。

## 2. 两个子 overlay

- `package` overlay：每日 Elpa / Melpa / Melpa stable 属性集 +
  EXWM 及依赖；
- `emacs` overlay：`emacs-git`（master）、`emacs-unstable`
  （最新 tag）、`-nox`（无 X）、`-pgtk`（原生 Wayland GTK）、
  `emacs-igc`（gc 分支）等。

## 3. 附加功能

- `emacsWithPackagesFromUsePackage`：解析 `use-package` / `leaf` /
  Org babel 配置自动收集包，支持 `alwaysEnsure`、`alwaysTangle`、
  `extraEmacsPackages`、`override`；另有一些辅助解析文件
  （`parse.nix` / `packreq.nix` / `repos/fromElisp`）。

## 4. 工程

- `overlays/emacs.nix` + `package.nix`；`repos/` 存 elpa/melpa/
  nongnu 索引；`update/` 每日刷新；
- flake 输出 `overlays.emacs/package/default`、`packages`、
  `lib`、`hydraJobs`（stable/unstable 两套 nixpkgs 构建全部
  emacs 变体与包集）；
- CI：ci.yml + pulls.yml，推 nix-community cachix。

## 5. 对我们仓库的启发

- 我们不用 Emacs，不引入；
- 它是“每日刷新生态包集 + 多 Emacs 变体 + hydraJobs 全量构建”
  的范例，和 nixpkgs-terraform-providers-bin / browser-previews
  的自动更新链路同构；
- `use-package` 配置解析成包集对我们做“配置即依赖”工具很有
  参考价值。

## 6. 参考

- [emacs-overlay](https://github.com/nix-community/emacs-overlay)
