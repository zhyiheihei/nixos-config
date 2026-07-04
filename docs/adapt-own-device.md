# 适配自己的 NixOS 设备

本文面向第一次接触这个项目的人，目标是把作者的 NixOS flake 配置迁移到自己的机器上，并尽量保留作者原本的 client 桌面体验。

示例主机名使用 `ml-2700u`。实际使用时，把它替换成自己的设备名。

## 1. 先理解项目结构

这个仓库不是单机 `configuration.nix` 风格，而是 flake + 多主机配置：

- `flake.nix`：定义 nixpkgs、home-manager、sops-nix、作者 NUR 等输入。
- `hosts/<hostname>/host.nix`：主机元数据，比如标签、位置、部署策略。
- `hosts/<hostname>/configuration.nix`：主机自己的系统配置和覆盖。
- `hosts/<hostname>/hardware-configuration.nix`：由 `nixos-generate-config` 生成的硬件配置。
- `nixos/client.nix`：作者的完整桌面客户端配置入口。
- `local-secrets/`：本地私有 secrets 仓库，不提交到主仓库。

适配新设备时，优先新增 `hosts/<hostname>/`，不要先改全局模块。全局模块越晚改，越容易保留作者原始行为。

## 2. 准备自己的 secrets 仓库

原作者的 `nixos-secrets` 是私有仓库，直接复用会 404。需要创建自己的私有仓库，例如：

```bash
git@github.com:<your-github>/nixos-secrets.git
```

主仓库的 `flake.nix` 里把 secrets input 指向自己的仓库：

```nix
secrets.url = "git+ssh://git@github.com/<your-github>/nixos-secrets.git";
```

如果 secrets 是私有仓库，新机器上建议用 SSH agent 转发访问 GitHub：

```bash
ssh -A root@<nixos-ip>
ssh -T git@github.com
```

成功时会看到类似：

```text
Hi <your-github>! You've successfully authenticated, but GitHub does not provide shell access.
```

## 3. 建立新 host

新增目录：

```text
hosts/ml-2700u/
├── host.nix
├── configuration.nix
└── hardware-configuration.nix
```

`host.nix` 用来声明这台机器是 client：

```nix
{ tags, geo, ... }:
{
  index = 113;
  tags = with tags; [
    client
  ];
  city = geo.cities."US Bellevue";
  manualDeploy = true;
}
```

`hardware-configuration.nix` 从目标机器生成：

```bash
nixos-generate-config --show-hardware-config
```

或者安装系统时直接复制 `/etc/nixos/hardware-configuration.nix`。

## 4. 写主机 configuration.nix

如果目标是复现作者的桌面 client，主机配置可以先保持很薄：

```nix
{
  lib,
  ...
}:
{
  imports = [
    ../../nixos/client.nix

    ./hardware-configuration.nix
  ];

  boot.loader.grub = {
    efiSupport = true;
    device = "nodev";
  };

  fileSystems."/" = lib.mkForce {
    device = "/dev/disk/by-uuid/<root-uuid>";
    fsType = "ext4";
  };

  sops.age.sshKeyPaths = lib.mkForce [ "/etc/ssh/ssh_host_ed25519_key" ];

  services.openssh.settings = {
    PasswordAuthentication = lib.mkOverride 40 true;
    PermitRootLogin = lib.mkOverride 40 "yes";
  };
}
```

这里有几个关键点：

- `../../nixos/client.nix` 会引入作者完整 KDE/client 配置。
- 作者配置默认带 impermanence，可能把 `/` 定义成 `tmpfs`；如果你的机器是普通 ext4 root，需要用 `lib.mkForce` 覆盖。
- 作者配置里 SOPS 可能默认找 `/nix/persistent/etc/ssh/...`；普通安装可先覆盖为 `/etc/ssh/ssh_host_ed25519_key`。
- SSH 密码登录和 root 登录只是迁移期兜底，等系统稳定后应改成只允许密钥。

## 5. 配置 SOPS secrets

目标机器上把 SSH host key 转成 age recipient：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix shell nixpkgs#ssh-to-age nixpkgs#sops -c bash
ssh-to-age -i /etc/ssh/ssh_host_ed25519_key.pub
```

把输出的 `age1...` 写入 secrets 仓库的 `.sops.yaml`：

```yaml
keys:
  - &ml_2700u age1xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

creation_rules:
  - path_regex: .*\.yaml$
    key_groups:
      - age:
          - *ml_2700u
```

作者 client 会引用一些通用 secret 文件。即使暂时没有真实密钥，也要先创建 SOPS 加密占位文件：

```text
common/default-pw.yaml
common/mcp.yaml
common/nix.yaml
common/oauth2-proxy.yaml
common/restic.yaml
common/sftp.yaml
common/smtp.yaml
common/v2ray.yaml
```

注意：不要提交明文 YAML。写入后立刻加密：

```bash
for f in common/*.yaml; do
  sops -e -i "$f"
done

grep -R "ENC\\|sops:" common/*.yaml
```

确认文件里有 `ENC[AES256_GCM` 和 `sops:` 后再提交推送。

## 6. 更新 flake lock

在目标机器 `/etc/nixos` 中：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nix flake update secrets
nixos-rebuild switch --flake .#ml-2700u -L
```

如果 Nix 还没有默认启用 flakes，所有 `nix` 命令都加：

```bash
nix --extra-experimental-features "nix-command flakes" flake update secrets
```

如果不在 `/etc/nixos` 运行，会看到：

```text
path "/root" does not contain a 'flake.nix'
```

这只是当前目录错了，先 `cd /etc/nixos`。

## 7. 常见报错

### secrets 仓库 404

症状：

```text
unable to download 'https://api.github.com/repos/.../nixos-secrets/commits/HEAD': HTTP error 404
```

原因通常是私有仓库用 `github:` 拉取，未认证。改成 SSH URL：

```nix
secrets.url = "git+ssh://git@github.com/<your-github>/nixos-secrets.git";
```

并确认目标机器上：

```bash
ssh -T git@github.com
```

### `nix-command` 或 `flakes` 未启用

症状：

```text
experimental Nix feature 'nix-command' is disabled
```

临时解决：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### root 文件系统冲突

症状：

```text
The option `fileSystems."/".fsType' has conflicting definition values
```

作者 impermanence 配置可能定义了 tmpfs root。普通安装先在 host 里强制覆盖：

```nix
fileSystems."/" = lib.mkForce {
  device = "/dev/disk/by-uuid/<root-uuid>";
  fsType = "ext4";
};
```

### 内核包重复定义

症状：

```text
The option `boot.kernelPackages' is defined multiple times
```

优先删除 host 里自己加的 `boot.kernelPackages`，让项目的 `nixos/minimal-components/kernel.nix` 接管。

### 没有 wheel/root 登录方式

症状：

```text
Neither the root account nor any wheel user has a password or SSH authorized key
```

在 secrets 仓库补用户 SSH 公钥，例如：

```text
ssh/lantian.nix
```

内容是公钥列表：

```nix
[
  "ssh-ed25519 AAAA... user@example"
]
```

### 缺少 SOPS 文件

症状：

```text
Cannot find path '.../common/default-pw.yaml' set in sops.secrets...
```

说明 secrets 仓库还没创建对应文件。按第 5 节创建并加密占位文件。

### 第三方下载源 404

作者 client 引入了很多第三方闭源或滚动二进制包。常见例子：

- `pkgs.nur-xddxdd.geolite2`：GeoLite release 过期。
- `nur-xddxdd.qq`：腾讯 QQ deb 文件改名或下架。

先尝试更新相关 input：

```bash
nix flake update nur-xddxdd
```

如果仍然 404，可以临时注释对应包，让系统先完成安装。例如 QQ 位于：

```text
home/client-apps/packages.nix
```

临时注释：

```nix
# (lib.hiPrio nur-xddxdd.qq)
```

这类处理不是放弃复现，而是先让基础系统起来，后续再单独修包。

### 构建中内存不足或死机

作者 client 包很多，第一次构建会下载和构建大量内容。内存较小的机器建议降低并行度：

```bash
nixos-rebuild switch --flake .#ml-2700u -L --cores 2 --max-jobs 1
```

也建议先检查：

```bash
free -h
df -h / /nix /tmp
```

## 8. AMD 核显注意事项

AMD 核显通常不需要像 NVIDIA 那样单独声明闭源驱动。基础路径是：

- kernel 自动加载 `amdgpu`
- Mesa 提供 OpenGL/Vulkan
- `hardware.graphics.enable = true` 启用图形用户态

当前作者 client 的 `nixos/client-components/xorg.nix` 偏 Intel 机器，包含：

```nix
intel-compute-runtime
intel-media-driver
intel-vaapi-driver
LIBVA_DRIVER_NAME = "iHD"
```

AMD 机器装好后建议检查：

```bash
lspci -k | grep -A3 -E "VGA|Display|3D"
vainfo
glxinfo -B
```

如需覆盖 VAAPI 驱动，可在自己的 host 中加：

```nix
environment.variables.LIBVA_DRIVER_NAME = lib.mkForce "radeonsi";
```

## 9. 迁移期原则

- 优先在 `hosts/<hostname>/configuration.nix` 里覆盖，不急着改全局模块。
- secrets 仓库必须私有，但仍然只提交加密文件和公钥。
- 闭源滚动包 404 时，先跳过阻塞包，让系统完成首次切换。
- 首次成功 rebuild 后，再逐步收紧 SSH 登录、安全策略和个性化应用。
