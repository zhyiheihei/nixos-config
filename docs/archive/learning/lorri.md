# lorri 学习笔记

## 1. 是什么

`lorri` 是 `nix-shell` 的开发替代品：它监视 `shell.nix` / `flake.nix` 及
相关依赖，在后台重建开发环境，并在下次 shell 提示符自动应用。

## 2. 工作方式

- `lorri daemon`：后台守护进程；
- `lorri watch`：注册并监视项目；
- `lorri hook bash/zsh/fish`：shell 集成，加载缓存环境；
- 缓存上次环境，即使 daemon 没跑也能立即加载旧环境；
- 环境变化后后台重建，几秒后新环境可用。

## 3. 与 nix-direnv 的区别

- `nix-direnv`：direnv 触发时求值，简单、无需常驻 daemon；
- `lorri`：daemon 常驻，持续监视依赖并主动重建；
- 两者都防止 GC 清掉项目依赖。

## 4. 设计要点

- 初次求值时解析 `nix-instantiate` 日志，收集“输入路径”；
- 对路径做 reduction，把 store 路径、channel symlink 等折叠成最小 watch 集合；
- 用 inotify/fsevent 监视路径；
- 为每个 `.drv` 建立 GC root，避免环境被回收。

## 5. 对我们仓库的启发

我们已经在用 `nix-direnv`（`.envrc` 的 `use flake`），不需要引入 lorri。
lorri 适合需要“切换分支后后台自动更新环境”的复杂开发机。

## 6. 参考

- [lorri](https://github.com/nix-community/lorri)
