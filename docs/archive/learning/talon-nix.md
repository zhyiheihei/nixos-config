# talon-nix 学习笔记

## 1. 是什么

`talon-nix` 是 adisbladis 维护的 Talon Voice（语音编程应用）自动
打包仓库：38 star，只支持最新版，因为上游不提供带版本的下载
URL，上游一升级表达式就会挂，需要重跑抓取脚本。

`src.json` 钉住版本和 sha256：

```json
{"sha256": "4722...", "version": "0.4.0"}
```

## 2. scrape.py：抓最新版并算 hash

- `scrape.py version`：抓 changelog.html，取第一个 `h1` 文本里的
  版本号；
- `scrape.py download`：流式下载 `talon-linux.tar.xz`，边下边算
  sha256，写进 `src.json`。

## 3. 打包方式：FHS 环境包专有闭源应用

`talon.nix` 分两层：

1. `stdenv.mkDerivation`：`fetchurl` 下载官方 tarball，装到
   `$out/opt/talon`；拷 udev 规则并删掉 `GROUP="plugdev"` 兼容 hack
   （NixOS 下会坏，见 nixpkgs#76482）；写 desktop entry，`bin/talon`
   做 symlink，`lib` 也链到 `$out`；
2. `buildFHSEnv`：`targetPkgs` 里塞满运行时依赖——Xorg 全套、
   wayland/wlroots/xwayland、dbus/fontconfig/glib、pulseaudio/udev、
   `gtk3-x11`、speechd，以及 `gfortran.cc` 的 lib（取 `lib` 输出
   避免无 -fPIC 的静态库）；`profile` 里设
   `QT_PLUGIN_PATH=/lib/plugins` 和 python numpy 的
   `LD_LIBRARY_PATH`。

overlay 提供 `talon` 包；NixOS module
`programs.talon.enable`：加 overlay、装包、把 udev 规则交给
`services.udev.packages`。

## 4. CI 与维护

- `scrape.yml`：每天 UTC 4:13 跑 `version` + `download`，`git commit
  -a -m "Bumped Talon" || true`（没变化就不提交），rebase 后 push；
- `nix-github-actions.yml`：用 `nix-github-actions` 输入生成矩阵，
  `nix build .#talon` 验证；
- renovate 管 nix 依赖和 lock 维护，Mergify 对 renovate PR 在
  `nix-build` 绿后自动 rebase 合并。

## 5. FAQ 里的关键经验

- Nix store 只读，Talon 无法自更新；需要自更新的用户改用
  `steam-run` 跑官方 `run.sh`；
- 旧系统托盘没图标时，仓库用 `snixembed` 补；
- beta 版 tarball 私有且每次变化，不做。

## 6. 对我们仓库的启发

- 我们不跑语音应用，不引入；
- “上游只有 latest URL → 定时抓取 + 流式算 hash + 自动 commit +
  构建验证”是专有二进制包的标准维护模板，zhyi-packages 以后包
  这类软件可直接照抄；
- `buildFHSEnv` + udev + desktop entry 的闭源 GUI 打包组合，
  是我们 NixOS 上跑专有桌面包的通用配方。

## 7. 参考

- [talon-nix](https://github.com/nix-community/talon-nix)
- [Talon Voice](https://talonvoice.com/)
