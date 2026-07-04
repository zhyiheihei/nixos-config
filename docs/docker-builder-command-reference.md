# Docker/NixOS 接力构建命令参考

本文只整理这次临时救急过程中实际用到或直接相关的命令，方便之后快速复制。

默认信息：

- 弱机器：`ml-2700u`
- 弱机器 IP：`192.168.3.237`
- 弱机器配置目录：`/etc/nixos`
- Docker 工作目录：`/work/nixos-config`
- Docker 容器名：`nix-builder`

## 1. SSH 基础操作

### 登录弱机器

```bash
ssh root@192.168.3.237
```

### 在弱机器上执行单条命令

```bash
ssh root@192.168.3.237 'hostname'
ssh root@192.168.3.237 'cd /etc/nixos && git status --short'
```

### 测试 SSH 是否可用

```bash
ssh root@192.168.3.237 true
```

成功时没有输出，直接返回 shell。

### 添加弱机器到 known_hosts

在 Docker 容器里：

```bash
ssh-keyscan 192.168.3.237 >> /root/.ssh/known_hosts
```

### 添加 GitHub 到 known_hosts

```bash
ssh-keyscan github.com >> /root/.ssh/known_hosts
```

### 测试 GitHub SSH key

```bash
ssh -T git@github.com
```

成功时通常会看到类似：

```text
Hi <username>! You've successfully authenticated, but GitHub does not provide shell access.
```

## 2. 把当前设备 SSH 公钥复制到弱机器

### Linux/macOS 有 ssh-copy-id 时

如果当前设备已经有 SSH key：

```bash
ssh-copy-id root@192.168.3.237
```

指定某个公钥：

```bash
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@192.168.3.237
```

### 没有 ssh-copy-id 时，手动追加公钥

查看当前设备公钥：

```bash
cat ~/.ssh/id_ed25519.pub
```

复制到弱机器：

```bash
cat ~/.ssh/id_ed25519.pub | ssh root@192.168.3.237 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

### Windows PowerShell 复制公钥

PowerShell：

```powershell
type $env:USERPROFILE\.ssh\id_ed25519.pub | ssh root@192.168.3.237 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

### 为 Docker builder 生成专用 key

PowerShell：

```powershell
ssh-keygen -t ed25519 -f C:\nix-builder\ssh\id_ed25519 -C nix-builder
```

查看公钥：

```powershell
type C:\nix-builder\ssh\id_ed25519.pub
```

把这个公钥加入弱机器：

```powershell
type C:\nix-builder\ssh\id_ed25519.pub | ssh root@192.168.3.237 "mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys"
```

进入 Docker 后修 key 权限：

```bash
chmod 700 /root/.ssh
chmod 600 /root/.ssh/id_ed25519
```

## 3. Docker 容器操作

### 启动并进入容器

PowerShell：

```powershell
cd C:\nix-builder
docker compose up -d
docker exec -it nix-builder sh
```

### 查看容器日志

```powershell
docker logs nix-builder
```

### 确认容器架构

Docker 容器里：

```bash
uname -m
```

## 4. Nix flakes / shell 命令

### 当前 shell 临时启用 flakes

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### 持久写入容器 nix.conf

```bash
printf "experimental-features = nix-command flakes\n" >> /etc/nix/nix.conf
printf "max-jobs = 2\n" >> /etc/nix/nix.conf
printf "cores = 6\n" >> /etc/nix/nix.conf
```

### 进入带工具的 shell

```bash
nix shell nixpkgs#git nixpkgs#openssh nixpkgs#rsync -c bash
```

带 `nixos-rebuild`：

```bash
nix shell nixpkgs#nixos-rebuild nixpkgs#openssh -c bash
```

### 查看 flake 输出

```bash
nix flake show
```

### 更新单个 flake 输入

这次 GeoLite 404 时用过：

```bash
nix flake update nur-xddxdd
```

## 5. NixOS 临时配置 swap

适用于 NixOS 虚拟机 builder 或弱机器本机。这个方法是临时 swap，重启后不会自动启用。

### 查看当前内存和 swap

```bash
free -h
swapon --show
```

如果 `交换` / `Swap` 是 `0B`，构建大型桌面闭包时很容易 OOM。

### 创建 8G 临时 swapfile

```bash
fallocate -l 8G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

确认：

```bash
free -h
swapon --show
```

### 如果 fallocate 不可用

有些文件系统不支持 `fallocate`。可以改用：

```bash
dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
```

### 临时关闭并删除 swapfile

确认没有构建任务在跑之后再执行：

```bash
swapoff /swapfile
rm /swapfile
```

### 持久化 swapfile

如果这台 NixOS 机器以后长期作为 builder，可以写进 NixOS 配置：

```nix
{
  swapDevices = [
    {
      device = "/swapfile";
      size = 8192;
    }
  ];
}
```

然后：

```bash
nixos-rebuild switch
```

## 6. 确认 Docker 和弱机器配置一致

### Docker 里查看当前仓库状态

```bash
cd /work/nixos-config
git rev-parse HEAD
git status --short
```

### 弱机器查看 `/etc/nixos` 状态

```bash
ssh root@192.168.3.237 'cd /etc/nixos && git rev-parse HEAD && git status --short'
```

### 从弱机器同步 `/etc/nixos` 到 Docker

```bash
cd /work
mv nixos-config nixos-config.before-sync.$(date +%Y%m%d%H%M%S) 2>/dev/null || true
mkdir -p nixos-config
rsync -a --delete \
  --exclude '/result' \
  root@192.168.3.237:/etc/nixos/ \
  /work/nixos-config/
cd /work/nixos-config
```

## 7. 确认构建目标

```bash
printf "container arch: "
uname -m
printf "target system: "
nix eval --raw .#nixosConfigurations.ml-2700u.pkgs.stdenv.hostPlatform.system
echo
printf "target host: "
nix eval --raw .#nixosConfigurations.ml-2700u.config.networking.hostName
echo
```

期望：

```text
container arch: x86_64
target system: x86_64-linux
target host: ml-2700u
```

## 8. nix copy：弱机器和 Docker 互相复制 store

### 从弱机器复制当前系统 closure 到 Docker

注意先在弱机器上解析 `/run/current-system`：

```bash
weak_system=$(ssh root@192.168.3.237 'readlink -f /run/current-system')
echo "$weak_system"
nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 "$weak_system"
```

### 从弱机器复制 `/etc/nixos/result` 到 Docker

```bash
weak_result=$(ssh root@192.168.3.237 'readlink -f /etc/nixos/result')
echo "$weak_result"
nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 "$weak_result"
```

### 从 Docker 推送当前 `result` 到弱机器

```bash
nix copy --to ssh-ng://root@192.168.3.237 $(readlink -f result)
```

### 批量把 Docker 已有 store path 推给弱机器

用于接力构建前，把 Docker 已经完成的部分交给弱机器：

```bash
nix path-info --all \
  | grep -v '\.drv$' \
  | xargs -r -n 200 nix copy --no-check-sigs --to 'ssh-ng://root@192.168.3.237?trusted=true'
```

如果仍然报签名问题，可在 `nix copy` 后加：

```bash
--option require-sigs false
```

### 查找并复制某个包的 store path

以 BrowserOS 为例：

```bash
ssh root@192.168.3.237 'find /nix/store -maxdepth 1 -iname "*browseros*" -print' > /tmp/browseros-paths
cat /tmp/browseros-paths
xargs -r nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 < /tmp/browseros-paths
```

以 Bitwarden 为例：

```bash
ssh root@192.168.3.237 'find /nix/store -maxdepth 1 -iname "*bitwarden-desktop*" -print' > /tmp/bitwarden-paths
cat /tmp/bitwarden-paths
xargs -r nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 < /tmp/bitwarden-paths
```

## 9. nix build 命令

### Docker 里构建 ml-2700u

```bash
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L \
  --option substituters "https://cache.nixos.org ssh-ng://root@192.168.3.237" \
  --option require-sigs false \
  --option max-jobs 2 \
  --option cores 6
```

### 弱机器上用 nix build 构建

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L \
  --option max-jobs 2 \
  --option cores 4
```

## 10. nixos-rebuild 命令

### 弱机器 build，不切换系统

这是这次发现更短的写法：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild build --flake .#ml-2700u -L --max-jobs 2 --cores 4
```

### 从 Docker 远程触发弱机器 build

```bash
ssh root@192.168.3.237 'cd /etc/nixos && export NIX_CONFIG="experimental-features = nix-command flakes" && nixos-rebuild build --flake .#ml-2700u -L --max-jobs 2 --cores 4'
```

### 弱机器切换系统

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild switch --flake .#ml-2700u -L
```

### 从 Docker 远程触发弱机器 switch

```bash
ssh root@192.168.3.237 'cd /etc/nixos && export NIX_CONFIG="experimental-features = nix-command flakes" && nixos-rebuild switch --flake .#ml-2700u -L'
```

## 11. 常见报错对应命令

### experimental Nix feature 'nix-command' is disabled

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

或单次命令：

```bash
NIX_CONFIG="experimental-features = nix-command flakes" nix flake show
```

### fatal: repository 'printf' does not exist

说明把命令粘成一行了。重新分行执行：

```bash
printf "experimental-features = nix-command flakes\n" >> /etc/nix/nix.conf
export NIX_CONFIG="experimental-features = nix-command flakes"
```

### lacks a signature by a trusted key

从弱机器拉到 Docker：

```bash
nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 /nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-name
```

从 Docker 推到弱机器：

```bash
nix copy --no-check-sigs --to 'ssh-ng://root@192.168.3.237?trusted=true' /nix/store/xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx-name
```

构建时把弱机器当 substituter：

```bash
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L \
  --option substituters "https://cache.nixos.org ssh-ng://root@192.168.3.237" \
  --option require-sigs false
```

### /run/current-system: No such file or directory

不要直接复制远程 symlink。先解析：

```bash
weak_system=$(ssh root@192.168.3.237 'readlink -f /run/current-system')
nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 "$weak_system"
```
