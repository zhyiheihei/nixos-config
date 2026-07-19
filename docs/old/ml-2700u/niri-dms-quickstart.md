# Niri 与 DMS 桌面快速入门

`ml-2700u` 使用 Niri 作为 Wayland 合成器，使用 Dank Material Shell（DMS）
提供状态栏、启动器、通知、控制中心、壁纸和锁屏。首次登录出现的
`DMS 1.4` 窗口属于桌面组件，不是安装残留。

当前仓库实际启用的是 DMS `1.4.6`。配置入口：

- `nixos/client-components/niri.nix`
- `home/client-apps/niri.nix`

## 理解窗口布局

Niri 把平铺窗口排列成一条可以横向滚动的长带：

- 左右方向切换窗口列。
- 同一列存在多个窗口时，上下方向切换列内窗口。
- 工作区整体按上下方向排列。
- `Mod` 表示键盘的 Win/Super 键。

## 最常用快捷键

| 操作 | 快捷键 |
| --- | --- |
| 向左或向右切换窗口列 | `Win + Left/Right` |
| 在同一列内上下切换窗口 | `Win + Up/Down` |
| 向左或向右移动当前窗口列 | `Win + Ctrl + Left/Right` |
| 打开窗口总览 | `Win + O` |
| 打开终端 | `Win + T` |
| 关闭窗口 | `Win + Q` 或 `Alt + F4` |
| 切换 1/3、1/2、2/3 列宽 | `Win + R` |
| 最大化当前列 | `Win + F` |
| 当前窗口全屏 | `Win + Shift + F` |
| 居中当前列 | `Win + C` |
| 切换浮动状态 | `Win + V` |
| 显示完整快捷键帮助 | `Win + Shift + /` |

## 工作区

| 操作 | 快捷键 |
| --- | --- |
| 切换到工作区 1 至 9 | `Win + 1` 至 `Win + 9` |
| 上下切换工作区 | `Win + PageUp/PageDown` |
| 把当前列移到工作区 1 至 9 | `Win + Ctrl + 1` 至 `Win + Ctrl + 9` |
| 把当前列移到相邻工作区 | `Win + Ctrl + PageUp/PageDown` |

刚开始只需记住 `Win + Left/Right`、`Win + O`、`Win + R` 和 `Win + Q`。
遇到忘记的操作，按 `Win + Shift + /` 查看 Niri 自带快捷键面板。

