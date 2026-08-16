# home-manager 学习笔记

## 1. 是什么

`home-manager` 是 Nix 生态里事实标准的 **用户环境声明式管理工具**
（MIT，10196 star）。它用 Nix 声明用户级包、dotfile、systemd user
service、dconf、终端/编辑器/桌面应用配置，支持三种接入方式：

- standalone：独立 `home-manager` 命令，任何有 Nix 的平台可用；
- NixOS module：随 `nixos-rebuild` 一起构建用户 profile；
- nix-darwin module：随 `darwin-rebuild` 一起构建。

项目面向 `nixpkgs-unstable` 开发，同时为每个 NixOS release 维护
`release-*` 分支；README 明确警告：能力越强越容易覆盖手写配置
（例如 Gnome Terminal 写 dconf），建议从小配置逐步扩展。

## 2. 结构

仓库是单 flake：

- `modules/`：按 `programs` / `services` / `files` / `misc` /
  `i18n` / `targets` / `accounts` 等分类的数百个选项模块；
- `lib/`：模块求值和 bash/python 辅助库，负责把声明翻译成
  activation 动作；
- `nixos/` 与 `nix-darwin/`：系统模块入口，提供
  `home-manager.users.<name>` 并做用户 profile 管理；
- `home-manager/`：CLI、gettext 翻译、formatter；
- `tests/`：单元测试 + NixOS integration tests；
- `templates/`：standalone / nixos / nix-darwin 模板。

flake 输出 `nixosModules.home-manager`、`darwinModules`、
`flakeModules`、`lib` 和分块测试包；CI 把几千个测试按每块约 50 个
切分，配合 nixbot/buildbot 并行跑。

## 3. 关键机制

- 每个用户一个 generation，切换后生成新的 `/home/<user>` 状态，
  支持 `home-manager rollback` 回滚；
- activation 阶段执行“先备份旧文件、再按声明创建 symlink/生成
  配置”的脚本，冲突文件会留备份而不是直接覆盖；
- 与 NixOS module 集成时，系统构建和用户构建共享同一 nixpkgs，
  避免 store 里出现两套包；
- 提供 `programs.bash/zsh/fish` 等完整模块，也支持“裸配置 + 任意
  package”的组合。

## 4. CI 与发布

- 用 nixbot 跑分块测试、docs 和 integration tests；
- Weblate 做 gettext 翻译；
- 文档由 mdBook 生成到 GitHub Pages，options 文档可直接搜索；
- 发布按 NixOS release 分支进行，fix 通常会 backport。

## 5. 对我们仓库的启发

我们仓库的 `home/` 目录就是 Home Manager 配置（client.nix /
common-apps / non-client-apps），当前路线是“NixOS module 集成”：

- 用户级包和 dotfile 交给 home-manager，系统级包留在 NixOS
  module，职责边界清晰；
- 新模块放进 `home/common-apps/` 或 `home/non-client-apps/`，
  跟 NixOS 侧的 `nixos/<role>-apps/` 分层对应；
- 升级 Home Manager 前应看 release branch 的 news，避免模块选项
  大改导致用户配置失效。

## 6. 参考

- [home-manager](https://github.com/nix-community/home-manager)
- [Home Manager 手册](https://nix-community.github.io/home-manager/)
- [Options 搜索](https://home-manager-options.extranix.com/)
