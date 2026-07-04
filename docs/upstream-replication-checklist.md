# 一比一复刻原作者项目检查表

本文以 `reference-project/` 作为原作者项目基准，对比当前仓库，记录要完整复刻需要准备什么。

当前目标：先让测试机 `ml-builder` 按原作者项目原版逻辑跑通，再逐步接入其它机器。

## 1. 对比结论

### 已与原版一致

- [x] `nixos/minimal-components/users.nix`
  - 主用户是 `lantian`
  - `root` 和 `lantian` 共用 `inputs.secrets + "/ssh/lantian.nix"` 的 SSH 公钥
  - 密码 hash 来自 `glauthUsers.lantian.passBcrypt`
  - userborn 密码文件路径是 `/nix/persistent/var/lib/nixos`

- [x] `nixos/minimal-components/home-manager.nix`
  - Home Manager 用户是 `root` 和 `lantian`

- [x] `nixos/minimal-components/impermanence.nix`
  - `/` 是 tmpfs
  - 持久化入口是 `/nix/persistent`
  - SOPS 默认使用 `/nix/persistent/etc/ssh/ssh_host_ed25519_key`

- [x] `nixos/client-components/impermanence.nix`
  - 客户端 home 持久化路径是 `/home/lantian`

- [x] `nixos/client-components/xorg.nix`
  - 图形会话相关用户是 `lantian`

- [x] `nixos/minimal-components/ssh-harden.nix` 逻辑与原版一致
  - 当前差异主要是中文注释
  - SSH 服务端口仍是 `2222`
  - `authorizedKeysInHomedir = false`
  - OpenSSH host key 仍指向 `/nix/persistent/etc/ssh/...`

### 与原版存在实质差异

- [ ] `flake.nix` channel 与输入不一致
  - 原版：`nixpkgs = nixos-unstable`
  - 当前：`nixpkgs = nixos-26.05`
  - 原版还有 `dms`、`niri-flake` 输入，当前已移除
  - 当前 `secrets` 指向你的 `git+ssh://git@github.com/zhyiheihei/nixos-secrets.git`，这是必要替换

- [ ] `nixos/client-components/kde.nix` 不符合原版
  - 原版中 KDE 模块整段注释，最后是空模块：
    ```nix
    _: { }
    ```
  - 当前启用了 Plasma/greetd/KDE 相关配置
  - 如果目标是一比一复刻原版，应恢复成原版；如果目标是你的 KDE 客户端，应明确这是个人改造

- [ ] `README.md` 与原版不同
  - 当前声明了 fork 来源和你的文档
  - 这对复刻运行无影响，但不是字面原版

- [ ] `hosts/ml-builder/*` 是你新增的测试机，不可能与原版完全相同
  - 可以参考原版 `hosts/lt-home-builder/*`
  - 但 IP、磁盘、CPU、SSH host key、ZeroTier、公网 IPv6 都必须用你的真实环境

- [ ] `local-secrets/` 不是原作者 secrets 仓库
  - 当前只具备基础占位结构
  - 原作者的很多 optional/server 模块需要更多 secrets 文件
  - 只跑 `minimal.nix` + `nix-builder` 时，先满足基础文件即可

## 2. ml-builder 复刻作者构建机需要准备

原作者构建机参考：

```text
reference-project/hosts/lt-home-builder/
```

当前你的测试机构建目标：

```text
hosts/ml-builder/
```

### 磁盘与启动

- [ ] 已给 VM 建快照
- [ ] 已确认启动模式是 BIOS 还是 UEFI
- [ ] 如果是 BIOS，`boot.loader.grub.device` 指向真实磁盘，例如 `/dev/sda`
- [ ] 如果是 UEFI，改成 `efiSupport = true; device = "nodev";`
- [ ] `/boot` 是独立持久分区
- [ ] `/nix` 是 btrfs
- [ ] 不再配置普通 ext4 `/`
- [ ] 切换后确认 `/` 是 tmpfs
- [ ] 切换后确认 `/nix/persistent` 存在

当前仓库假设的测试机布局：

```text
/dev/sda1 -> /boot, ext4
/dev/sda2 -> /nix, btrfs
/         -> tmpfs
```

如果实际不是这个布局，先改：

```text
hosts/ml-builder/hardware-configuration.nix
```

### 用户与 SSH

- [x] 系统用户名已恢复为 `lantian`
- [x] `root` 和 `lantian` 已读取 `ssh/lantian.nix`
- [x] `local-secrets/ssh/lantian.nix` 已有你的 Mac 公钥
- [ ] `local-secrets/ssh/nix-builder.nix` 有用于远程构建的客户端公钥
- [ ] `local-secrets` 已提交并推送到 GitHub
- [ ] 目标机已 `nix flake update secrets`
- [ ] 切换后 `id lantian` 成功
- [ ] 切换后 `id nix-builder` 成功
- [ ] Mac 能执行 `ssh -p 2222 lantian@192.168.3.176`
- [ ] Mac 能执行 `ssh -p 2222 nix-builder@192.168.3.176 true`

注意：原版 `ssh-harden.nix` 禁止读取用户家目录里的 `~/.ssh/authorized_keys`。登录公钥必须来自 secrets 仓库里的 Nix 文件。

### SOPS 与 secrets

- [x] `local-secrets/.sops.yaml` 已有 `ml_builder` recipient
- [ ] recipient 来自目标机最终持久化 host key：
  ```text
  /nix/persistent/etc/ssh/ssh_host_ed25519_key.pub
  ```
- [ ] `common/*.yaml` 已重新加密给 `ml_builder`
- [ ] `local-secrets/common/default-pw.yaml` 存在
- [ ] `local-secrets/common/mcp.yaml` 存在
- [ ] `local-secrets/common/nix.yaml` 存在
- [ ] `local-secrets/common/oauth2-proxy.yaml` 存在
- [ ] `local-secrets/common/restic.yaml` 存在
- [ ] `local-secrets/common/sftp.yaml` 存在
- [ ] `local-secrets/common/smtp.yaml` 存在
- [ ] `local-secrets/common/v2ray.yaml` 存在
- [ ] 切换后 `sops-install-secrets.service` 成功

### 网络与主机元数据

原作者 `lt-home-builder` 有：

```nix
zerotier = "...";
firewalled = true;
public.IPv6 = "...";
interconnect = {
  name = "home-lan";
  IPv4 = "...";
  IPv6 = "...";
};
```

你当前的 `ml-builder` 还没准备这些，所以暂时是手动测试机。

- [x] `host.nix` 有 `lan-access` 和 `nix-builder` 标签
- [x] `host.nix` 有 `cpuThreads`
- [x] `host.nix` 有 `ssh.ed25519`
- [ ] ZeroTier node id 已准备
- [ ] 公网 IPv6 已准备
- [ ] home-lan/interconnect IPv4 已准备
- [ ] home-lan/interconnect IPv6 已准备
- [ ] DNS 能解析到类似 `ml-builder.lantian.pub` 的名字
- [ ] 决定是否保留 `manualDeploy = true`

如果还没有域名和 ZeroTier，先用手动 builder：

```bash
nix build nixpkgs#hello -L \
  --builders "ssh-ng://nix-builder@192.168.3.176 x86_64-linux 1 6 - - -" \
  --option builders-use-substitutes true
```

## 3. 原版构建机功能差距

原版 `lt-home-builder/configuration.nix` 额外启用了：

```nix
../../nixos/optional-apps/hydra
../../nixos/optional-apps/ncps-client.nix
lantian.backup.enable = true;
systemd.network.networks.eth0 = { ... };
```

当前 `ml-builder/configuration.nix` 只导入：

```nix
../../nixos/minimal.nix
./hardware-configuration.nix
```

要复刻原版构建机，需要准备：

- [ ] Hydra 需要的 secrets：
  - `common/attic.yaml`
  - `hydra.yaml`
- [ ] Attic 服务或兼容缓存服务
- [ ] backup 所需：
  - `common/restic.yaml`
  - `common/sftp.yaml`
  - 可用的 Storage Box 或替代 SFTP 目标
- [ ] `ncps-client.nix` 所需网络环境
- [ ] 静态网络配置：
  - IPv4 地址
  - gateway
  - IPv6 token
  - MTU
- [ ] 确认是否要启用 `../../nixos/optional-apps/attic-watch-store.nix`

建议顺序：

1. 先只跑通 `minimal.nix`
2. 再跑通 `nix-builder` SSH 远程构建
3. 再接入 Attic
4. 最后接入 Hydra、backup、ncps

## 4. client 复刻差距

如果后续要复刻作者客户端，而不是只跑构建机，需要处理：

- [ ] `nixos/client-components/kde.nix` 是否恢复原版空模块
- [ ] `reference-project/home/client-apps/niri.nix` 当前缺失
- [ ] `reference-project/nixos/client-components/niri.nix` 当前缺失
- [ ] `reference-project/helpers/wallpaper/wallpaper.jpg` 当前缺失
- [ ] 当前新增的 `home/client-apps/ulauncher-extensions.nix` 是否保留
- [ ] 当前新增的 `nixos/client-apps/ulauncher.nix` 是否保留

如果目标是“一比一原版”，应优先恢复缺失的 `niri` 与 wallpaper，并把 KDE 模块恢复成原版。

如果目标是“原版架构 + 你的 KDE 桌面”，则保留当前 KDE，但文档里要明确这是个人差异。

## 5. flake 与锁文件

- [ ] 决定是否恢复原版 `nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable"`
- [ ] 决定是否恢复原版 `nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-25.05"`
- [ ] 决定是否恢复 `dms`
- [ ] 决定是否恢复 `niri-flake`
- [ ] 决定是否恢复 `stylix = "github:make-42/stylix/matugen"`
- [ ] `secrets` 保持替换为你的私有仓库
- [ ] 更新 `flake.lock`

注意：如果继续使用 `nixos-26.05`，很多“包要本地 built”的现象可能和原作者不一致。严格复刻时，flake 输入也应尽量回到原版。

## 6. 当前最小可执行路线

先不要一次性打开所有原版服务。

- [x] 主用户恢复 `lantian`
- [x] userborn 路径恢复 `/nix/persistent/var/lib/nixos`
- [x] Home Manager 用户恢复 `lantian`
- [x] SSH host key 路径恢复 `/nix/persistent/etc/ssh`
- [ ] VM 磁盘按 `/boot` + btrfs `/nix` 准备好
- [ ] secrets 推送成功
- [ ] 目标机更新 secrets lock
- [ ] `nix build .#nixosConfigurations.ml-builder.config.system.build.toplevel -L` 成功
- [ ] `nixos-rebuild switch --flake .#ml-builder -L` 成功
- [ ] `ssh -p 2222 lantian@192.168.3.176` 成功
- [ ] `ssh -p 2222 nix-builder@192.168.3.176 true` 成功

这条路线跑通后，再考虑 Hydra、Attic、backup、ZeroTier、DNS。不要同时打开太多模块，否则排错会再次变成一团。
