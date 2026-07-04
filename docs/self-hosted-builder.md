# 使用 NAS Attic 和 Windows Docker 强机器做 NixOS 构建缓存

本文目标是把当前仓库的重型 NixOS client 构建从 `ml-2700u` 这类弱机器上挪走。

最终结构：

```text
NAS
  -> Docker 跑 Attic server，保存 binary cache

Windows 强机器
  -> Docker Desktop 跑 Linux GitHub self-hosted runner
  -> runner 执行 nix build
  -> 构建完成后 push 到 NAS Attic

ml-2700u
  -> nixos-rebuild 时优先从 NAS Attic 下载
  -> 缓存缺失时才本机编译
```

这条路线适合当前仓库，因为完整 client 配置包含 KDE、Home Manager、NUR、patched nixpkgs、自定义 kernel/module 等大量内容。Cachix 免费容量只有 5GB，不适合保存完整桌面系统闭包；Attic 的容量由自己的 NAS 磁盘决定。

## 0. 准备信息

先确定这些值，后面命令里会反复用到：

```text
NAS_IP        = 你的 NAS 局域网 IP，例如 192.168.3.10
ATTIC_SERVER  = http://NAS_IP:8080
ATTIC_CACHE   = nixos
GITHUB_REPO   = https://github.com/zhyiheihei/nixos-config
HOST_NAME     = ml-2700u
```

网络必须满足：

- Windows Docker runner 能访问 GitHub。
- Windows Docker runner 能访问 `ATTIC_SERVER`。
- `ml-2700u` 能访问 `ATTIC_SERVER`。
- Windows Docker runner 能通过 SSH 拉取私有 `nixos-secrets` 仓库。

## 1. 在 NAS 上启动 Attic

先用最小可用部署跑起来。下面示例假设 NAS 上有 Docker Compose，并把数据放到 `/srv/attic`：

```bash
mkdir -p /srv/attic/config
mkdir -p /srv/attic/storage
```

创建 `/srv/attic/compose.yml`：

```yaml
services:
  attic:
    image: nixos/nix:latest
    container_name: attic
    restart: unless-stopped
    ports:
      - "8080:8080"
    volumes:
      - ./config:/root/.config/attic
      - ./storage:/var/lib/attic
      - attic-nix-store:/nix
    command: >
      sh -lc '
        printf "experimental-features = nix-command flakes\n" > /etc/nix/nix.conf &&
        nix shell github:zhaofengli/attic -c atticd
      '

volumes:
  attic-nix-store:
```

启动：

```bash
cd /srv/attic
docker compose up -d
docker logs -f attic
```

第一次启动时，Attic 会输出登录用的 root token。把它先保存下来，后面要用。

如果这里报 `atticd` 找不到，进入容器手动确认 Attic flake app 名称：

```bash
docker exec -it attic sh
nix shell github:zhaofengli/attic -c atticd
```

这一步的目标很简单：浏览器或命令行能访问 `http://NAS_IP:8080`，并且日志里没有持续重启。

## 2. 初始化 Attic cache

在任意一台能访问 NAS 的 Linux/Nix 环境里执行。可以先在 NAS 容器里做，也可以在 `ml-2700u` 上做。

进入 Attic client 环境：

```bash
nix --extra-experimental-features "nix-command flakes" shell github:zhaofengli/attic -c bash
```

登录：

```bash
attic login local http://NAS_IP:8080 <第一步日志里的 root token>
```

创建 cache：

```bash
attic cache create nixos
attic cache configure nixos --public
```

生成给 GitHub Actions 用的 push token：

```bash
atticadm make-token --sub github-actions --validity "1 year" --pull nixos --push nixos
```

记下这个 token，后面放到 GitHub Secret `ATTIC_TOKEN`。

查看 Nix 客户端需要的 substituter 和 public key：

```bash
attic use nixos
```

它会输出类似：

```text
extra-substituters = http://NAS_IP:8080/nixos
extra-trusted-public-keys = nixos:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx=
```

把 public key 也保存下来，后面要写进 `ml-2700u` 配置。

## 3. 准备私有 secrets 仓库读取权限

当前主仓库的 `flake.nix` 会通过 SSH 读取：

```text
git+ssh://git@github.com/zhyiheihei/nixos-secrets.git
```

所以 GitHub runner 必须有一把可以读取 `nixos-secrets` 的 SSH 私钥。

推荐做法：

1. 在本地生成一把专用 deploy key。
2. 把公钥添加到 `zhyiheihei/nixos-secrets` 的 Deploy keys，权限只给 read。
3. 把私钥全文保存到主仓库的 Actions Secret：`DEPLOY_KEY`。

不要复用自己的日常 SSH 私钥。

## 4. 配置 GitHub Actions 变量

进入主仓库：

```text
Settings -> Secrets and variables -> Actions
```

添加 Secrets：

```text
DEPLOY_KEY    = 读取 nixos-secrets 的 SSH 私钥
ATTIC_TOKEN   = 第二步生成的 push token
```

添加 Variables：

```text
ATTIC_SERVER  = http://NAS_IP:8080
ATTIC_CACHE   = nixos
```

如果后面 workflow 显示没有推送缓存，优先检查这四个值。

## 5. 在 Windows Docker Desktop 上跑 Linux runner

强机器是 Windows 没问题，但 runner 要跑在 Linux 容器里。不要直接注册 Windows runner，因为当前构建目标是 NixOS Linux 系统闭包。

要求：

- Docker Desktop 使用 Linux containers。
- Docker Desktop 分配足够磁盘，建议至少 200GB。
- runner 容器有持久化 `/nix` volume。
- runner 标签必须包含 `nix-builder`。

在 GitHub 主仓库创建 runner：

```text
Settings -> Actions -> Runners -> New self-hosted runner
```

选择：

```text
Linux
x64
```

注册标签至少包含：

```text
self-hosted
linux
x64
nix-builder
```

如果用第三方 runner 镜像，核心 compose 结构应当类似：

```yaml
services:
  runner:
    image: <github-runner-image>
    container_name: github-runner-nix-builder
    restart: unless-stopped
    privileged: true
    environment:
      REPO_URL: https://github.com/zhyiheihei/nixos-config
      RUNNER_NAME: win-docker-nix-builder
      LABELS: linux,x64,nix-builder
    volumes:
      - runner-work:/runner/_work
      - nix-store:/nix

volumes:
  runner-work:
  nix-store:
```

不同 runner 镜像的环境变量名字不完全一样，以你选的镜像文档为准。这里最关键的是标签、Linux 容器、持久化 `/nix`。

runner 注册成功后，GitHub 页面里应该看到它处于 `Idle` 或 `Online`。

## 6. 使用仓库里的构建工作流

本仓库新增了：

```text
.github/workflows/build-nixos-self-hosted.yml
```

它只支持手动触发：

```text
Actions -> Build NixOS on self-hosted runner -> Run workflow
```

输入：

```text
host = ml-2700u
```

workflow 会做这些事：

1. checkout 主仓库。
2. 用 `DEPLOY_KEY` 配置 SSH，读取私有 `nixos-secrets`。
3. 安装 Nix。
4. 构建：

```bash
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel
```

5. 把 `result` 的完整 closure 推送到 Attic：

```bash
attic push nixos <closure paths>
```

构建成功后，后续同一份 flake.lock、patch、overlay、host 配置就可以从 Attic 命中缓存。

## 7. 让 ml-2700u 使用 NAS Attic

把第二步 `attic use nixos` 输出的 substituter 和 public key 写进 `ml-2700u` 的配置。

可以先放到 `hosts/ml-2700u/configuration.nix`：

```nix
{
  nix.settings.substituters = [
    "http://NAS_IP:8080/nixos"
    "https://cache.nixos.org"
  ];

  nix.settings.trusted-public-keys = [
    "nixos:xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx="
  ];
}
```

如果以后多台机器都要用，建议抽成一个公共模块。

然后在 `ml-2700u` 上执行：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild switch --flake .#ml-2700u -L
```

命中缓存时，日志里会大量出现：

```text
copying path
```

如果还是大量出现：

```text
building
```

通常说明强机器还没成功 push，或者当前 `flake.lock` / 配置和强机器构建时不一致。

## 8. 把弱机器已有缓存先推到 Attic

如果 `ml-2700u` 已经成功构建过一部分，可以在 Attic 准备好之后先推当前系统闭包：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
nix shell github:zhaofengli/attic -c bash
attic login local http://NAS_IP:8080 <有 push 权限的 token>
attic push nixos $(nix path-info -r /run/current-system)
```

如果 `/etc/nixos/result` 存在，也可以推它的闭包：

```bash
cd /etc/nixos
attic push nixos $(nix path-info -r ./result)
```

这只能复用已经有完整 store path 的内容，不能保证把失败构建中途的临时产物都救回来。

## 9. 故障排查顺序

先查 runner 是否在线：

```text
GitHub -> Settings -> Actions -> Runners
```

再查 runner 是否能访问 NAS：

```bash
curl http://NAS_IP:8080
```

再查私有 secrets 仓库是否能拉：

```bash
ssh -T git@github.com
git ls-remote git@github.com:zhyiheihei/nixos-secrets.git
```

再查 Attic 登录和推送：

```bash
attic login ci http://NAS_IP:8080 <token>
attic cache list
```

最后查弱机器是否信任缓存：

```bash
nix config show substituters
nix config show trusted-public-keys
```

## 10. 当前推荐节奏

按这个顺序做：

1. NAS 上先跑起 Attic。
2. 创建 `nixos` cache，拿到 public key 和 push token。
3. GitHub 配好 `ATTIC_SERVER`、`ATTIC_CACHE`、`ATTIC_TOKEN`、`DEPLOY_KEY`。
4. Windows Docker Desktop 跑起 Linux self-hosted runner。
5. 手动触发 `Build NixOS on self-hosted runner`。
6. 成功后把 Attic substituter 写进 `ml-2700u`。
7. `ml-2700u` 重新 `nixos-rebuild switch`，观察是否从 `building` 变成大量 `copying path`。
