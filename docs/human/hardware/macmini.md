# Mac mini（aarch64-darwin）接入与维护

Mac mini 是自有机队中**唯一的 macOS / nix-darwin 主机**，与其余 NixOS
主机的接入路径不同：不参与 Colmena，不由 `make build`/`make all` 构建，而是通过
flake 的 `darwinConfigurations` 单独求值，用 `darwin-rebuild` 在本机部署。

## 主机身份

- 主机名：`macmini`（`hostname` = `macmini.zhyi.cc`，`interconnect.IPv4` = `192.168.0.54`）
- `host.nix`：[`hosts/macmini/host.nix`](../../../hosts/macmini/host.nix)
- `index = 115`，`system = "aarch64-darwin"`，标签 `macos` / `lan-access`
- `manualDeploy = true`（Colmena 不默认选择，且 darwin 本就不走 Colmena）
- 登录用户：`molishanguang`（非项目其他主机的 `zhyi`），沿用现有 macOS 用户，
  不重建用户、不迁移家目录。

## 部署机制

### flake 接入

`flake-modules/darwin-configurations.nix` 从 `hosts/` 里自动筛选
`system` 含 `"darwin"` 的主机，用 `inputs.nix-darwin.lib.darwinSystem` 求值，
模块组合为：

- `hosts/<n>/darwin-configuration.nix`（系统级）
- `inputs.stylix.darwinModules.stylix`（darwin 侧 stylix，见下）
- `inputs.home-manager.darwinModules.home-manager`（用户级）
- `hosts/<n>/home.nix`（又 `import ../../home/macos.nix` 跨平台集）

darwin 侧用**干净 nixpkgs**（不开 Linux-only overlay），且 `import inputs.nixpkgs`
时显式 `config.allowUnfree = true`（NixOS 侧靠用户级 `~/.config/nixpkgs/config.nix`
放行，darwin 用 `useGlobalPkgs` 全局 pkgs 不读用户级配置）。

### darwin-rebuild 命令（在 macmini 本机执行）

```bash
sudo darwin-rebuild switch --flake /Users/molishanguang/nixos-config#macmini --impure
```

新版 `darwin-rebuild` 要求 system activation 以 root 运行，必须加 `sudo`
（旧版可普通用户运行，新版会报 `system activation must now be run as root`）。
`--flake` 指向本地仓库；`--impure` 允许访问本机网络/缓存源。

## 网络与 substituter

macmini 与 NixOS 主机走同一套 nix 配置（`nix.settings`，与 `ncps-client.nix`
同机制，`LT.nix` 常量同源）：

```nix
nix.settings.substituters = [
  "http://${LT.hosts.opi5p.interconnect.IPv4}:${LT.portStr.Ncps}"  # opi5p 本地代理
  LT.nix.attic.url                                                  # attic 自有缓存兜底
];
nix.settings.trusted-public-keys = [ LT.nix.attic.publicKey ];
```

前提是 Mac 上卸载 Determinate Nix（Determinate 占 `/etc/nix/nix.conf` 会与
`nix.settings` 冲突），改用 nix-darwin 原生管理的 Nix。

> **darwin 二进制缓存缺口**：`opi5p` 的 ncps 上游是 SJTU 镜像，**无
> aarch64-darwin 二进制**，对 macmini 无效。macmini 首次构建大量闭包时若 attic
> 也无对应路径，会退化到慢速外网。预拉 darwin 路径并导入本机 store 的完整
> 加速方案见 [darwin 闭包导入加速](./migrations/macmini-darwin-import.md)。

## 接入注意点（踩坑记录）

### stylix 与 darwin 的边界

- darwin 侧 `stylix.targets` 只有 `font-packages` / `jankyborders` / `neovim`，
  不能照搬 NixOS 的 `console` / `qt` / `kmscon`。
- `cursor` 的 nur-xddxdd 包在干净 nixpkgs 下不可用，darwin 侧不设 cursor。
- `enableReleaseChecks = false`，且 `homeManagerIntegration.followSystem = false`
  （followSystem 默认注入 copyModules 引用 `osConfig`，darwin 只提供 darwinConfig，
  会求值失败）。
- 不用 image + matugen：matugen 的 flake 只暴露 linux systems，darwin 无 package。
  显式设 `base16Scheme` 指向 stylix 自带 tinted-schemes。

### 首次接管点文件

`home-manager.backupFileExtension = "hm-bak"`：首次接管已有 `.gitconfig` 等
点文件时自动备份而非中断激活，防止 `would be clobbered` abort。

### /etc 冲突

新版本 nix-darwin activation 会因 `/etc/bashrc`、`/etc/zshrc` 存在「未识别内容」
而中止（提示 `Unexpected files in /etc, aborting activation`）。处理：按提示把
文件改名加 `.before-nix-darwin` 后缀（内容仅 Nix 环境加载，无用户关键数据），
再重跑 `darwin-rebuild switch`。

### 家目录私有配置

`home/macos.nix` 只挑跨平台 common-apps + 少量 client-apps（git/hushlogin/
mercurial/sops/yt-dlp/zsh），排除 bash.nix（Mac 用 zsh，且 `~/.bash_profile`
有 Homebrew 镜像配置不该被接管覆盖）。macOS 特有私有配置在
`hosts/macmini/home.nix` 补：Homebrew USTC 镜像、Hermes PATH、Edge debug alias
（`zsh.initExtra`）与 `git.http/https.proxy`（走 `192.168.0.1:1080` 家庭代理）。

## SSH

macmini 是 macOS，OpenSSH 走 **22 端口**（非项目默认 2222）。接入命令：

```bash
ssh -o IdentitiesOnly=yes -i ~/.ssh/id_ed25519 molishanguang@192.168.0.54
```

- 登录私钥是项目同一把 `id_ed25519`；host key 指纹在 `host.nix` 已登记。
- **不要 `-A` 转发 agent 到 macmini**（agent 转发会导致 poll 认证失败）。
- 项目 SSH config 未给 macmini 建别名时，显式带 `-i` 和用户名连接即可。

## 维护

- 系统状态：`/run/current-system` → `nix/store/<hash>-darwin-system-<rev>`
- 版本：`/run/current-system/sw/bin/darwin-version`
- nix-daemon 日志：`/var/log/nix-daemon.log`
