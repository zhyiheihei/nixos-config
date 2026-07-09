# 同步上游后逐台切换系统

本文记录 fork 同步上游之后，如何把每台机器逐步切换到最新配置。

目标是保留自己的提交，同时吸收原作者的新提交；切换时先保守逐台验证，再考虑使用作者同款 Colmena 批量部署。

## 1. 同步仓库

在本地 `nixos-config` 仓库：

```bash
git status
git fetch upstream
git rebase upstream/master
```

如果上游主分支不是 `master`，改成实际分支名。

遇到冲突时：

```bash
git status
```

手动解决冲突后：

```bash
git add <conflicted-file>
git rebase --continue
```

如果本次同步完全不对，才使用：

```bash
git rebase --abort
```

rebase 完成后推回自己的 fork：

```bash
git push --force-with-lease origin master

```

强制以远端为准

```bash
cd /nix/src/nixos-config
git fetch origin
git reset --hard origin/master
git clean -fd
```

## 2. 先构建，不切换

先在强机器或缓存机器上构建目标 host，确认 eval 和 build 能过。

例如在强机器 `ml-builder`：

```bash
cd /nix/src/nixos-config
git fetch origin
git reset --hard origin/master

nix build .#nixosConfigurations.ml-builder.config.system.build.toplevel -L
nix build .#nixosConfigurations.ml-builder-cache.config.system.build.toplevel -L
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L
```

长时间构建可以放到 `tmux`：

```bash
nix shell nixpkgs#tmux -c tmux new -s nix-build
```

构建完成后，Attic 自动上传服务会把新闭包推到缓存。也可以手动全量推送，见：

```text
docs/attic-full-store-push.md
```

## 3. 单台机器手动切换

当前你的机器里，`host.nix` 写了 `manualDeploy = true` 的机器不适合直接批量自动切换。先在每台机器上手动执行。

### ml-builder

```bash
ssh -A -p 2222 root@192.168.3.192
cd /nix/src/nixos-config
git fetch origin
git reset --hard origin/master
nixos-rebuild switch --flake .#ml-builder -L
```

切换后检查：

```bash
hostname
systemctl --failed
nix config show | grep -E '^(substituters|trusted-public-keys) ='
git config --global user.name
git config --global user.email
```

### ml-builder-cache

```bash
ssh -A -p 2222 root@192.168.2.135
cd /nix/src/nixos-config
git fetch origin
git reset --hard origin/master
nixos-rebuild switch --flake .#ml-builder-cache -L
```

切换后重点检查 Attic 和 Hydra：

```bash
systemctl status atticd.service --no-pager -l
systemctl status attic-watch-store.service --no-pager -l
systemctl status hydra-server.service --no-pager -l
systemctl status hydra-queue-runner.service --no-pager -l
systemctl status hydra-attic-repush.timer --no-pager -l
```

验证缓存可读：

```bash
nix path-info --store https://attic.zhyi.cc:4000/lantian /run/current-system
```

如果这条找不到当前系统闭包，不一定是错误；可能只是当前系统还没有推送进 Attic。先看 `attic-watch-store` 日志：

```bash
journalctl -u attic-watch-store.service -n 100 --no-pager
```

### ml-2700u

弱机器尽量只拉缓存，不在本机大量编译。

```bash
ssh -A root@192.168.3.237
cd /etc/nixos
git fetch origin
git reset --hard origin/master
nixos-rebuild switch --flake .#ml-2700u -L
```

如果是在安装镜像中安装到 `/mnt`，使用：

```bash
cd /mnt/etc/nixos
NIX_CONFIG='extra-experimental-features = nix-command flakes
extra-substituters = https://attic.zhyi.cc:4000/lantian
extra-trusted-public-keys = lantian:1NwML/pv7MO0K3az6Zrb7NNd+X5MehGH5B0B4S111QA=' \
nixos-install --flake path:/mnt/etc/nixos#ml-2700u --no-root-passwd -L
```

如果安装镜像没有继承项目里的 Nix 配置，就需要像上面这样临时传入 Attic substituter 和 public key。

## 4. 作者的自动切换方式

作者仓库使用 Colmena 做自动/批量部署。入口在 `Makefile`：

```makefile
servers:
	nix run .#colmena -- apply --on @server

all:
	nix run .#colmena -- apply --on @default

all-all:
	nix run .#colmena -- apply --on @all

local:
	nix run .#colmena -- apply --on $(shell cat /etc/hostname)
```

Colmena 的连接信息来自每台机器的 `hosts/<host>/host.nix`：

```nix
hostname = "...";
sshPort = ...;
manualDeploy = true;
tags = with tags; [ ... ];
```

底层 deployment 模块会把这些字段转成：

```nix
deployment.targetHost = hostname;
deployment.targetPort = sshPort;
deployment.targetUser = "root";
deployment.tags = LT.tagsForHost LT.this;
```

所以作者不是靠每台机器自己定时 `nixos-rebuild switch`，而是从控制端用 Colmena 按 host/tag 推送切换。

## 5. 什么时候可以用 Colmena

你的新机器稳定前，建议保持：

```nix
manualDeploy = true;
```

此时走本文第 3 节逐台手动切换。

等满足这些条件后，再考虑放开批量部署：

- SSH host key 已写入对应 `host.nix`
- `hostname` 和 `sshPort` 都正确
- root SSH 登录稳定
- secrets 可以正常解密
- Attic substituter 和 public key 正常
- 单机 `nixos-rebuild switch` 至少成功过一次
- 回滚路径明确，最好有虚拟机快照或远程控制台

然后可以尝试单机 Colmena：

```bash
nix run .#colmena -- apply --on ml-builder-cache
```

或在目标机器本机：

```bash
make local
```

确认稳定后再按标签：

```bash
make servers
make all
```

`make all-all` 和带 `--reboot` 的目标影响面更大，只适合所有 host 都整理好之后使用。

## 6. 推荐更新顺序

当前阶段建议顺序：

1. `ml-builder-cache`

   先保证 Attic/Hydra/cache 服务稳定。缓存机稳定后，其他机器切换可以吃缓存。

2. `ml-builder`

   强机器负责重包构建、缓存推送、日常验证。

3. `ml-2700u`

   弱机器最后切，尽量只拉缓存。若出现大量本地构建，先回到强机器补构建和推缓存。

## 7. 常见问题

### flake.lock 冲突

如果冲突发生在 `secrets` 输入，要确认保留自己的 secrets 仓库：

```text
git@github.com:zhyiheihei/nixos-secrets.git
```

不要误回到作者的：

```text
xddxdd/nixos-secrets
```

### 切换后 Git 作者变成 Lan Tian

检查：

```bash
git config --global user.name
git config --global user.email
git config --global user.signingkey
```

对应配置在：

```text
home/common-apps/tunings.nix
home/client-apps/git.nix
```

### 缓存没有命中

先确认系统信任的 key：

```bash
nix config show | grep -E '^(substituters|trusted-public-keys) ='
```

当前 Attic key 应包含：

```text
lantian:1NwML/pv7MO0K3az6Zrb7NNd+X5MehGH5B0B4S111QA=
```

如果安装镜像或临时环境没有项目配置，需要临时用 `NIX_CONFIG` 传入 substituter 和 key。
