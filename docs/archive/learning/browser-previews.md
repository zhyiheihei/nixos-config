# browser-previews 学习笔记

## 1. 是什么

`browser-previews` 是 r-k-b 维护的 flake，提供最新的
`google-chrome` / `google-chrome-beta` / `google-chrome-dev` 三个
channel 的 Nix 包。55 star；起因是 nixpkgs 删掉了 beta/dev
（[NixOS/nixpkgs#261870](https://github.com/NixOS/nixpkgs/pull/261870)），
这里作为“新鲜版本补充仓库”独立存在。

```bash
NIXPKGS_ALLOW_UNFREE=1 nix run github:nix-community/browser-previews#google-chrome-dev --impure
```

flake 只支持 `x86_64-linux`；包是 Google 官方 .deb 的 unfree 二进制。

## 2. 包构建

`google-chrome/default.nix` 基本复制 nixpkgs 的 google-chrome 打包
（README 标明出处），关键点：

- 从 `dl.google.com/linux/chrome/deb/pool/main/g` 下载
  `google-chrome-{stable,beta,unstable}_<version>-1_amd64.deb`
  （带镜像 fallback），固定 SRI hash；
- `ar x` + `tar xf data.tar.xz` 解包，`patchelf` 重设 rpath 和
  dynamic linker；
- `makeWrapper` 注入 `LD_LIBRARY_PATH` / `PATH` / `XDG_DATA_DIRS`，
  `CHROME_WRAPPER`，并处理 `NIXOS_OZONE_WL` 的 Wayland flags；
- 替换桌面文件、menu、图标路径，适配三个 channel 的名字；
- `meta.platforms = [ "x86_64-linux" ]`，`license = unfree`。

版本数据在 `upstream-info.nix`：每个 channel 的 `version` +
`hash_deb_amd64`，stable 还带 chromedriver 三个平台的 hash。

## 3. update.py：版本钉住与自动更新

`update.py` 借鉴 nixpkgs chromium 的更新脚本：

1. 查 Chrome Version History API
   （`versionhistory.googleapis.com/v1/chrome/.../releases`）；
2. 只处理 `upstream-info.nix` 里已有的 channel，按时间取最新 release；
3. 用 `nix store prefetch-file` 预取 .deb 得到 SRI hash（失败的
   release 视为“还没发布”，跳过）；
4. stable 额外从
   `googlechromelabs.github.io/chrome-for-testing/last-known-good...`
   拿 chromedriver 版本和三个平台 hash；
5. 用 `nix-instantiate --eval --expr '{ json }: fromJSON json'` +
   `nixfmt` 把 JSON 写回 Nix 文件；
6. `--commit` 模式按 channel 逐个提交，stable 的提交信息由
   `get-commit-message.py` 从 Chrome Releases 官方博客 feed 抓取
   （版本、安全修复说明、CVE 列表）。

## 4. CI：每天自动 bump

`bump.yml` 每天约 AEST 6am 跑：

1. `cachix/install-nix-action` + `magic-nix-cache`；
2. `nix develop`（devShell 带 python feedparser/looseversion/requests、
   nix-prefetch-git、nixfmt-rfc-style）；
3. 配 `BumpBot` 身份，只在 `main` 上跑 `./google-chrome/update.py
   --commit`；
4. `NIXPKGS_ALLOW_UNFREE=1 nix flake check --impure` 验证三个 channel
   都能构建；
5. `git push` 直接推回 main（PR 场景没有推送权限时
   continue-on-error）。

dependabot 管 GitHub Actions（每天）和 Nix 依赖（每周）。

## 5. 对我们仓库的启发

- 我们没有 x86_64 桌面跑 Chrome beta/dev 的需求，不引入；
- “官方 API 取版本 + prefetch 固定 hash + 定时任务自动提交”和
  nvfetcher 思路一致，但比 nvfetcher 更贴近 nixpkgs 包结构；
- `nix-instantiate --eval --expr '{ json }: fromJSON json'` 把 JSON
  转回格式化 Nix 的小技巧，我们做数据驱动的 .nix 生成时可以直接用；
- 若 zhyi-packages 未来要补“nixpkgs 缺失的每日二进制包”，这个
  仓库是标准模板。

## 6. 参考

- [browser-previews](https://github.com/nix-community/browser-previews)
- [nixpkgs google-chrome](https://github.com/NixOS/nixpkgs/tree/master/pkgs/applications/networking/browsers/google-chrome)
