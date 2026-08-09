# plasma-manager 学习笔记

## 1. 是什么

`plasma-manager` 是 HeitorAugustoLN 维护的项目：用 **Home Manager
模块声明式配置 KDE Plasma**（MIT，1210 star，2026-08 仍在活跃）。
默认分支 `trunk` 面向 Plasma 6；Plasma 5 用户用 `plasma-5` 分支。

## 2. 支持范围

- `files`：直接写 KDE 配置文件；
- `workspace`：全局主题/配色/图标/光标/壁纸；
- `desktop`、`panels`、`shortcuts`、`hotkeys`、`input`（键盘/
  触摸板/鼠标）、`krunner`、`kscreenlocker`、`fonts`、
  `window-rules`、`session`；
- `apps`：ghostwriter / kate / konsole / okular 等应用模块。

## 3. 两种使用方式

- 默认：只写你指定的配置，其他设置保留（适合与 GUI 混用）；
- `overrideConfig = true`：登录时把所有未设置项重置为默认，
  变成完全声明式（会**删除现有 KDE 配置文件**，需先备份）。

## 4. rc2nix

仓库带 `rc2nix` 工具：读取现有 KDE 配置文件转成 Nix，方便迁移
和 diff 追踪 GUI 改动；生成结果不一定最优，但适合起步。

## 5. 工程

- `modules/`（option 定义）+ `script/`（生成配置）+ `lib/` +
  `test/` + `docs/`；flake 提供 homeManagerModules；
- 不支持需要 root 的 Plasma 登录屏配置；实时生效需要重新登录。

## 6. 对我们仓库的启发

- 我们没有 Plasma 桌面，不引入；
- 它是“桌面配置即代码”的代表：声明式 + 迁移工具 + 双分支
  （Plasma 5/6），与 stylix（已学）等互补；
- 若以后给 client 主机配 KDE，可直接用它的 Home Manager 模块。

## 7. 参考

- [plasma-manager](https://github.com/nix-community/plasma-manager)
