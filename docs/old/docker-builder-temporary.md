# 使用 Docker 强机器临时构建并传给弱机器

本文是临时方案，不依赖 GitHub Actions，也不依赖 Attic。

适用场景：

- `ml-2700u` 本机编译太慢或内存不够。
- 手头有一台 Windows 强机器，只能跑 Docker Desktop。
- 想先把系统构建出来，再把构建结果传给弱机器使用。

长期方案仍然推荐 [NAS Attic 和 Windows Docker 强机器](./self-hosted-builder.md)。本文方案更像一次性救急：强机器构建，弱机器复用强机器的 `/nix/store` 产物。

## 0. 整体流程

```text
Windows 强机器
  -> Docker Desktop 跑 Linux 容器
  -> 容器里安装/使用 Nix
  -> clone 当前 nixos-config 仓库
  -> nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel
  -> nix copy --to ssh-ng://root@ml-2700u <result path>

ml-2700u
  -> 收到完整 closure
  -> 本机 nixos-rebuild 时大部分内容直接命中本地 /nix/store
```

这个方案不会自动维护公共 binary cache。换一台机器或更新 flake 后，通常要重新构建和复制。

## 1. 先确认 Windows 强机器环境

下面命令都在 Windows 强机器上执行。建议打开：

```text
开始菜单 -> PowerShell
```

确认 Docker Desktop 已启动：

```powershell
docker version
```

能看到 `Server` 信息才算 Docker 正常。如果只看到 `Client`，说明 Docker Desktop 还没启动。

确认当前使用 Linux containers：

```powershell
docker info
```

输出里应当能看到：

```text
OSType: linux
```

如果不是 Linux containers，在 Docker Desktop 托盘菜单里切换到 Linux containers。

Docker Desktop 磁盘建议至少 200GB：

```text
Docker Desktop -> Settings -> Resources -> Disk image size
```

这个构建会吃很多磁盘。空间太小会中途失败，而且错误信息通常不太友好。

## 2. 确认弱机器能 SSH 登录

弱机器 `ml-2700u`：

- OpenSSH 已开启。
- root 或目标用户可以 SSH 登录。
- NixOS 配置仓库在 `/etc/nixos`。

在 Windows PowerShell 或你的 Mac 上确认能登录：

```powershell
ssh root@192.168.3.237
```

如果每次都要输密码，可以先把公钥放上去。macOS 可以执行：

```bash
ssh-copy-id root@192.168.3.237
```

Windows 上如果没有 `ssh-copy-id`，可以先继续用密码登录；后面 `nix copy` 时也会提示输入密码。长期看还是建议配置公钥。

## 3. 创建 Docker 工作目录

回到 Windows PowerShell，创建工作目录：

```powershell
mkdir C:\nix-builder
mkdir C:\nix-builder\work
mkdir C:\nix-builder\ssh
cd C:\nix-builder
```

创建 `compose.yml`。最省心的办法是用记事本：

```powershell
notepad C:\nix-builder\compose.yml
```

粘贴以下内容并保存：

```yaml
services:
  nix-builder:
    image: nixos/nix:latest
    container_name: nix-builder
    restart: unless-stopped
    tty: true
    stdin_open: true
    volumes:
      - nix-store:/nix
      - ./work:/work
      - ./ssh:/root/.ssh
    working_dir: /work
    command: sleep infinity

volumes:
  nix-store:
```

目录结构现在应该类似：

```text
C:\nix-builder
├── compose.yml
├── ssh\
└── work\
```

其中：

- `work`：放仓库代码。
- `ssh`：放 SSH key 和 known_hosts。
- `nix-store`：Docker volume，保存 `/nix`，不会直接显示成普通文件夹。

## 4. 启动 Nix builder 容器

启动：

```powershell
cd C:\nix-builder
docker compose up -d
```

确认容器正在运行：

```powershell
docker ps
```

应该看到：

```text
nix-builder
```

进入容器：

```powershell
docker exec -it nix-builder sh
```

进入后命令提示符会变成类似：

```text
sh-5.2#
```

从这里开始，命令是在 Linux 容器里执行，不是在 Windows PowerShell 里执行。

`nix-store` 这个 volume 很重要。它让第一次构建后的 store 留在强机器上，后续重试不会从零开始。

## 5. 配置容器里的 Nix

在容器里执行：

```bash
printf "experimental-features = nix-command flakes\n" >> /etc/nix/nix.conf
printf "max-jobs = 2\n" >> /etc/nix/nix.conf
printf "cores = 6\n" >> /etc/nix/nix.conf
```

根据强机器配置调整：

- `max-jobs`：同时构建几个 derivation。
- `cores`：每个 derivation 最多使用几个核心。

比如 8 核 16 线程机器可以先用：

```text
max-jobs = 2
cores = 6
```

不要一开始拉满。Nix 构建会同时跑很多 C++/Rust 编译，CPU 拉满时内存和磁盘也会一起爆。

确认 Nix flakes 可用：

```bash
nix --extra-experimental-features "nix-command flakes" --version
```

## 6. 准备 SSH key

容器需要两类 SSH 能力：

1. 拉私有 `nixos-secrets` 仓库。
2. 把构建结果推给 `ml-2700u`。

### 方式 A：使用专用 key

推荐给这个 builder 单独准备一把 SSH key，不要复用日常主力私钥。

在 Windows PowerShell 里执行：

```powershell
ssh-keygen -t ed25519 -f C:\nix-builder\ssh\id_ed25519 -C nix-builder
```

它会生成：

```text
C:\nix-builder\ssh\id_ed25519
C:\nix-builder\ssh\id_ed25519.pub
```

然后把 `id_ed25519.pub` 的内容添加到两个地方：

1. GitHub 账号或 `nixos-secrets` 仓库 Deploy key，用来读取私有 secrets。
2. `ml-2700u` 的 `/root/.ssh/authorized_keys`，用来让强机器推送 `/nix/store`。

查看公钥内容：

```powershell
type C:\nix-builder\ssh\id_ed25519.pub
```

### 方式 B：临时复制已有 key

如果只是临时测试，也可以把已有 key 复制到：

```text
C:\nix-builder\ssh\id_ed25519
C:\nix-builder\ssh\id_ed25519.pub
```

这条路更快，但安全性差一点，用完建议删掉。

### 在容器里修权限

先进入带 OpenSSH 的临时 shell：

```bash
nix shell nixpkgs#openssh -c bash
```

权限在 Windows 上可能不严格，修一下：

```bash
chmod 700 /root/.ssh
chmod 600 /root/.ssh/id_ed25519
```

如果 `/root/.ssh/id_ed25519` 不存在，说明 Windows 里的 `C:\nix-builder\ssh` 没有正确挂载或 key 没放进去。

添加 GitHub 和弱机器 known_hosts：

```bash
ssh-keyscan github.com >> /root/.ssh/known_hosts
ssh-keyscan 192.168.3.237 >> /root/.ssh/known_hosts
```

测试：

```bash
ssh -T git@github.com
ssh root@192.168.3.237 true
```

如果 GitHub 成功，会看到类似：

```text
Hi zhyiheihei! You've successfully authenticated, but GitHub does not provide shell access.
```

弱机器测试成功时，`ssh root@192.168.3.237 true` 应该没有输出，直接回到命令行。

如果这里失败，先别继续构建。先把 SSH 打通，不然后面 `nix copy` 还是会卡住。

## 7. 拉取仓库

重新进入带 Git 和 OpenSSH 的临时 shell：

```bash
nix shell nixpkgs#git nixpkgs#openssh -c bash
```

进入后 clone 主仓库：

```bash
cd /work
git clone git@github.com:zhyiheihei/nixos-config.git
cd nixos-config
```

如果主仓库是公开仓库，也可以用 HTTPS clone：

```bash
git clone https://github.com/zhyiheihei/nixos-config.git
cd nixos-config
```

但 `flake.nix` 里的 `nixos-secrets` 是 SSH 私有输入，所以 SSH key 仍然需要可用。

确认 flake 能看到目标 host：

```bash
nix flake show
```

如果这里提示不能读取 `nixos-secrets`，就是 GitHub SSH key 权限还没配好。

## 8. 在强机器容器里构建

构建 `ml-2700u`：

```bash
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L
```

如果担心太吃资源：

```bash
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L \
  --option max-jobs 2 \
  --option cores 6
```

构建成功后会生成：

```text
./result -> /nix/store/...-nixos-system-ml-2700u-...
```

查看结果路径：

```bash
readlink -f result
```

查看完整 closure 大小：

```bash
nix path-info -Sh ./result
```

## 9. 强机器主动推给弱机器

这是最推荐的临时方式。

在强机器容器里执行：

```bash
nix copy --to ssh-ng://root@192.168.3.237 $(readlink -f result)
```

这会把 `result` 依赖的完整 closure 复制到弱机器的 `/nix/store`。

如果提示找不到 `ssh`，先进一个带 OpenSSH 的临时环境：

```bash
nix shell nixpkgs#openssh -c bash
cd /work/nixos-config
nix copy --to ssh-ng://root@192.168.3.237 $(readlink -f result)
```

复制完成后，在弱机器上执行：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild switch --flake .#ml-2700u -L
```

如果配置和强机器构建时一致，弱机器应该大量复用本地 store，明显减少 `building`。

## 10. 弱机器主动从强机器拉

这个方向也能做，但临时方案里不如主动推简单。

弱机器想主动拉，需要满足：

- 强机器容器能被弱机器 SSH 访问。
- 容器里有 SSH server。
- 弱机器知道要拉哪个 `/nix/store/...` 路径。

如果只是为了救急，不建议折腾这个方向。Windows Docker Desktop 的容器网络和端口映射会让这条路更麻烦。

更现实的做法是：

1. 强机器构建。
2. 强机器 `nix copy --to ssh-ng://root@弱机器` 主动推。
3. 弱机器本机 `nixos-rebuild switch`。

## 11. 后续重试

以后重新进入容器：

```powershell
cd C:\nix-builder
docker compose up -d
docker exec -it nix-builder sh
```

进入仓库更新：

```bash
cd /work/nixos-config
git pull
nix flake update secrets
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L \
  --option max-jobs 2 \
  --option cores 6
```

再推给弱机器：

```bash
nix copy --to ssh-ng://root@192.168.3.237 $(readlink -f result)
```

## 12. 常见问题

### docker 命令找不到

说明 Docker Desktop 没装好，或者 PowerShell 没拿到 Docker 命令。先打开 Docker Desktop，再重新打开 PowerShell。

### docker compose up 很快退出

查看日志：

```powershell
docker logs nix-builder
```

正常情况下容器会一直运行，因为 compose 里写了：

```text
command: sleep infinity
```

### git clone 私有仓库失败

先在容器里测试：

```bash
ssh -T git@github.com
```

如果不是 `Hi zhyiheihei`，就是 GitHub SSH key 没配好。

### nix copy 到弱机器失败

先测试：

```bash
ssh root@192.168.3.237 true
```

如果这条不通，`nix copy` 一定不通。先修弱机器 SSH 登录。

### 弱机器仍然大量 building

通常是强机器构建的仓库状态和弱机器 `/etc/nixos` 不一致。

检查两边：

```bash
git rev-parse HEAD
git status --short
```

`flake.lock`、`hosts/ml-2700u`、`patches`、`overlays` 这些影响构建的内容必须一致。

## 13. 和 Attic 方案的区别

临时 Docker 方案：

- 搭建快。
- 适合先救一台弱机器。
- 不需要 NAS Attic。
- 没有统一 binary cache。
- 多台机器复用不方便。

Attic 方案：

- 初次搭建更麻烦。
- 适合长期使用。
- 多台机器都能拉缓存。
- GitHub runner 构建后自动推 cache。
- 更接近真正的个人 Nix 基建。

当前建议：

```text
短期：Docker 强机器构建后 nix copy 给 ml-2700u
长期：Windows Docker runner + NAS Attic
```
