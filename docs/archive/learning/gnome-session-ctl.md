# gnome-session-ctl 学习笔记

## 1. 是什么

`gnome-session-ctl` 是 jtojnar 从 gnome-session 里拆出来的小 C
工具（GPL-2.0+，3 star，2026-03 仍在维护，版本号 50.0 跟随
gnome-session）。GNOME 3.38.0 起 gnome-session 加了它，而
gnome-settings-daemon 需要它，造成循环依赖；拆成独立包后依赖图
变成 README 里那张图（settings-daemon → gnome-session-ctl →
gnome-session）。

## 2. 功能

`gnome-session-ctl` 通过 D-Bus 管理 GNOME 的 systemd session：

- `--signal-init`：通知 `org.gnome.SessionManager` 已初始化；
- `--start-shutdown-target` / `--start-restart-target` 等：调
  `org.freedesktop.systemd1.Manager.StartUnit` 启停目标；
- `--restart-dbus`：重启会话 dbus；
- 支持 systemd `sd_notify`（Type=notify）。

## 3. 构建

- `meson.build`：依赖 gio / glib / libsystemd，装进 `libexecdir`；
- 只一个 C 文件，无测试。

## 4. 对我们仓库的启发

- 我们不用 GNOME 桌面，不引入；
- 它是“拆包解循环依赖”的干净样例：把公共小工具独立成包，让
  两个大包互不依赖；zhyi-packages 或 nixpkgs 打包遇到循环依赖时
  可照此处理；
- 版本跟随上游（50.0 = gnome-session 50）也值得沿用。

## 5. 参考

- [gnome-session-ctl](https://github.com/nix-community/gnome-session-ctl)
