# nix-emacs 学习笔记

## 1. 是什么

`nix-emacs` 是一组 Emacs Lisp 包，让 Emacs 用户可以浏览和补全 NixOS
options / packages，并在编辑环境里使用 `nix-shell` 沙箱。MIT 协议，
2015 年由 Travis B. Hartwell、Diego Berrocal 等人创建，后移交
nix-community。仓库没有 flake/NixOS 模块，纯 ELisp，通过 MELPA 分发。

## 2. 包含的包

- `nixos-options`：核心包，加载 NixOS options 数据，提供浏览、文档
  查看和插入；
- `nixos-packages`：用 `nix-env -qaP --json` 生成包列表（代码里有
  spacemacs cache 目录假设）；
- `helm-nixos-options` / `ivy-nixos-options` / `company-nixos-options`：
  三种补全前端；
- `nix-sandbox`：`nix-shell` 沙箱集成，包括 `nix-shell-command`、
  `nix-compile`、`nix-executable-find`，并提供 flycheck 和
  haskell-mode 的包装示例。

## 3. 实现要点

- options 数据来源：`nix-build '<nixpkgs/nixos/release.nix>' -A options`
  产出的 `share/doc/nixos/options.json`，Emacs 启动时加载；
- 三个补全前端都围绕 `nixos-options` 的 alist 结构实现 candidate 和
  action（查看文档 / 插入 / pretty print）；
- `nix-sandbox` 用 `nix-shell --run 'declare +x shellHook; declare -x;
  declare -xf'` 生成环境 rc 快照并缓存，`nix-shell-command` 以
  `bash -c "source rc; cmd"` 方式在沙箱里跑命令，`nix-executable-find`
  用沙箱的 PATH 找可执行文件；
- 项目较老（2015 年起），README/TODO 还保留 Gitter、spacemacs 痕迹；
  仓库没有 GitHub Actions，纯 ELisp + MELPA 发布。

## 4. 与我们仓库的关系

- 我们仓库不使用 Emacs，不需要引入；
- `nix-sandbox` 的“沙箱环境快照 + PATH 代理”思路与我们在 zsh 里用
  direnv / `zsh-nix-shell` 做的事情类似；以后若给其它编辑器做
  nix-shell 集成，这个模式可以借鉴。

## 5. 参考

- [nix-emacs](https://github.com/nix-community/nix-emacs)
- [MELPA nixos-options](https://melpa.org/#/nixos-options)
