# nix-doom-emacs 学习笔记

## 1. 是什么

`nix-doom-emacs`（NDE）把 Doom Emacs 和用户自己的 `~/.doom.d` 配置打包成
可复现的 Nix derivation，并提供 Home Manager module（`hmModule`）。
MIT 协议，当前 243 star。

README 已明确标注 **Broken**：由于 Doom 与 emacs-overlay 的包集合长期
漂移，缺少 Elisp 包锁定机制，项目已一年多无法跟上 Doom 更新（跟踪
issue #353，更新 PR #316）。官方建议改用
`marienz/nix-doom-emacs-unstraightened`。

## 2. 使用方式

- Home Manager：`imports = [ nix-doom-emacs.hmModule ]`，然后设置
  `programs.doom-emacs.enable` 和 `doomPrivateDir`；
- NixOS：`nix-doom-emacs.packages.${system}.default.override {
  doomPrivateDir = ./doom.d; }` 放进 `environment.systemPackages`；
- standalone：`callPackage` 后 override；
- 可覆盖参数：`doomPackageDir`、`extraPackages`、`extraConfig`、
  `emacsPackages`、`emacsPackagesOverlay`、`bundledPackages`、
  `dependencyOverrides`。

## 3. 实现思路（多阶段构建）

1. `doomSrc`：对 Doom 源码打 `fix-paths.patch`，准备字节编译；
2. `doomLocal`：通过 `nix-straight.el` 把 `packages.el` 里的依赖收集成
   Nix 包，用 pinned flake inputs 提供源码，跑 `doom install --no-hooks
   --no-fonts --no-env` 并字节编译；构建若往 `$HOME` 写文件直接失败；
3. `doom-emacs`：应用 `nix-integration.patch`，去掉 Windows 的
   `doom.cmd`，`patchShebangs`；
4. `doomDir`：把 `extraConfig` 写成 `config.extra.el`，再用 workaround
   包装用户 `config.el`；
5. `emacs` wrapper：`emacsWithPackages` + site-lisp `default.el`，
   Emacs 29 用 `--init-directory`；最终把 `DOOMDIR` / `DOOMLOCALDIR`
   写进 wrapper 环境。

## 4. 依赖与工程

- flake 输入 pin 了 doom-emacs、emacs-overlay、nix-straight 以及十几个
  Doom 依赖仓库（evil-markdown、org-contrib、revealjs、format-all 等），
  支持 `dependencyOverrides` 单独换版本；
- `overrides.nix` 用 `straightBuild` 把 pinned 仓库包装成 emacs package，
  并对 magit、org、tree-sitter、dune 等特殊包做额外处理；
- CI：`check-build.yml` 在 x86_64 上构建 example、home-manager-module、
  emacsGit、splitdir 四个 checks，并用 nix-store dump 做缓存；
  `update-dependencies.yml` 自动更新 flake.lock / init.el 并开 PR。

## 5. 对我们仓库的启发

- 我们不用 Emacs/Doom，不引入；
- 教训：把 straight.el 这类“动态依赖安装”声明式化时，必须有稳定的
  包锁定机制；否则上游漂移会让项目长期处于 broken 状态；
- 多阶段构建和 CI store 缓存的思路可借鉴，但包锁定这一环是底线。

## 6. 参考

- [nix-doom-emacs](https://github.com/nix-community/nix-doom-emacs)
- [nix-straight.el](https://github.com/nix-community/nix-straight.el)
- [nix-doom-emacs-unstraightened](https://github.com/marienz/nix-doom-emacs-unstraightened)
- [Doom Emacs](https://github.com/doomemacs/doomemacs)
