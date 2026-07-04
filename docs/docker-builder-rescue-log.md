# 强机器接力构建 ml-2700u 实操日志

本文只记录这次实际跑过、踩过坑、修过的临时救急流程。

目标：

- 强机器可以是 Docker 容器，也可以是 NixOS 虚拟机。
- 强机器构建 `ml-2700u` 的 NixOS 系统闭包。
- 弱机器 `ml-2700u` 和强机器之间互相复制 `/nix/store`，尽量复用已经完成的构建产物。
- 遇到 Docker/sandbox 特有问题时，允许弱机器接力构建，再把结果拉回强机器。

本文不是长期方案。长期仍建议使用 Attic 或正式 remote builder。

## 1. 进入 builder

如果 builder 是 Docker 容器，Windows PowerShell：

```powershell
cd C:\nix-builder
docker compose up -d
docker exec -it nix-builder sh
```

进入容器后提示符类似：

```text
sh-5.3#
```

如果 builder 是 NixOS 虚拟机，直接 SSH 进去：

```bash
ssh root@<builder-vm-ip>
```

后续命令除特别说明外，都在 builder 里执行。

## 2. 在当前 shell 启用 flakes

临时救急时不要手写 `/etc/nix/nix.conf`。Docker 容器里可以写，但 NixOS 虚拟机的 `/etc/nix/nix.conf` 通常是系统生成的，可能是只读的。

统一用当前 shell 环境变量：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes
max-jobs = 2
cores = 6"
```

## 3. 进入带工具的临时 shell

builder 里不一定有 `git`、`ssh`、`rsync`。进入工具 shell：

```bash
nix shell nixpkgs#git nixpkgs#openssh nixpkgs#rsync -c bash
```

如果这里还报：

```text
experimental Nix feature 'nix-command' is disabled
```

先重新执行：

```bash
export NIX_CONFIG="experimental-features = nix-command flakes"
```

再跑 `nix shell ...`。

## 4. 以弱机器 /etc/nixos 为准同步配置树

这次发现 builder 里的 `git pull` 不一定等于弱机器实际使用的 `/etc/nixos`，尤其是弱机器有 dirty `flake.lock` 时。

最稳做法：把弱机器 `/etc/nixos` 当作唯一来源，同步到 builder。

先选一个 builder 本地工作目录：

```bash
# Docker 容器推荐
export BUILDER_WORKDIR=/work

# NixOS 虚拟机推荐二选一
# export BUILDER_WORKDIR=/root
# export BUILDER_WORKDIR=/srv
```

然后同步弱机器当前实际使用的 `/etc/nixos`：

```bash
mkdir -p "$BUILDER_WORKDIR"
cd "$BUILDER_WORKDIR"

if [ -e nixos-config ]; then
  mv nixos-config "nixos-config.before-sync.$(date +%Y%m%d%H%M%S)"
fi

mkdir -p nixos-config
rsync -a --delete \
  --exclude '/result' \
  root@192.168.3.237:/etc/nixos/ \
  "$BUILDER_WORKDIR/nixos-config/"

cd "$BUILDER_WORKDIR/nixos-config"
```

执行完后，当前目录应该是：

```bash
pwd
```

Docker 容器里通常是：

```text
/work/nixos-config
```

NixOS 虚拟机里通常是：

```text
/root/nixos-config
```

同步后对比两边 git 状态：

```bash
git rev-parse HEAD
git status --short
ssh root@192.168.3.237 'cd /etc/nixos && git rev-parse HEAD && git status --short'
```

这次看到两边一致，例如：

```text
dfe02bc317161025a5610516aeddbc242144447b
 M flake.lock
```

说明 builder 和弱机器使用的是同一份提交加同一份 dirty 修改。

## 5. 确认没有构建错 host 或架构

在 builder 里：

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

这次期望结果是：

```text
container arch: x86_64
target system: x86_64-linux
target host: ml-2700u
```

如果中间穿插：

```text
warning: Git tree '/root/nixos-config' is dirty
```

只说明当前工作树有未提交修改；只要 builder 和弱机器 dirty 状态一致即可。

## 6. 从弱机器预热 builder /nix/store

`nix copy --from` 需要真实 `/nix/store/...` 路径，不能直接写弱机器上的 `/run/current-system`，否则 builder 本地会报：

```text
error: getting status of "/run/current-system": No such file or directory
```

正确写法是先在弱机器上解析 symlink：

```bash
weak_system=$(ssh root@192.168.3.237 'readlink -f /run/current-system')
echo "$weak_system"
nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 "$weak_system"
```

`--no-check-sigs` 是因为弱机器本地 store 不是带 binary cache 签名的缓存；只对自己信任的机器这样用。

## 7. builder 里开始构建

builder 里最稳写法是 `nix build`：

```bash
nix build .#nixosConfigurations.ml-2700u.config.system.build.toplevel -L \
  --option substituters "https://cache.nixos.org ssh-ng://root@192.168.3.237" \
  --option require-sigs false \
  --option max-jobs 2 \
  --option cores 6
```

这里：

- `ssh-ng://root@192.168.3.237`：把弱机器临时当 substituter。
- `require-sigs false`：允许复用弱机器未签名的本地 store path。
- `max-jobs` / `cores`：避免 builder 把 CPU、内存、磁盘打满。

如果容器里装了 `nixos-rebuild`，也可以用更短写法：

```bash
nix shell nixpkgs#nixos-rebuild nixpkgs#openssh -c bash
nixos-rebuild build --flake .#ml-2700u -L --max-jobs 2 --cores 6
```

## 8. GeoLite2-ASN.mmdb 404 的处理

这次遇到：

```text
GeoLite2-ASN.mmdb
trying https://github.com/P3TERX/GeoLite.mmdb/releases/download/2026.06.13/GeoLite2-ASN.mmdb
curl: (22) The requested URL returned error: 404
error: cannot download GeoLite2-ASN.mmdb from any mirror
```

原因：`flake.lock` 里的 `nur-xddxdd` 锁到了已经失效的 GeoLite release。

处理：更新这个输入。

```bash
cd "$BUILDER_WORKDIR/nixos-config"
export NIX_CONFIG="experimental-features = nix-command flakes"
nix flake update nur-xddxdd
```

更新后如果弱机器 `/etc/nixos` 也要使用同一配置，必须同步更新后的 `flake.lock`。

## 9. BrowserOS AppImage hash mismatch 的处理

这次遇到：

```text
BrowserOS_v0.46.0_x64.AppImage
specified: sha256-zHADwaS3OlV1K6QaAudDTV1vXvgiEod/c=
got:       sha256-IV3Agg5i4TKDMQy+BjNbW6sqPsLfPcSOQkOADHhSmTw=
```

原因：上游同名 AppImage 内容变了，固定输出 hash 不匹配。弱机器没报错，是因为弱机器可能已经有旧 store path，不需要重新下载。

本次临时处理：在 `home/client-apps/packages.nix` 里注释掉：

```nix
# Disabled temporarily: upstream v0.46.0 AppImage is mutable and currently mismatches the hash pinned in nur-xddxdd.
# nur-xddxdd.browseros
```

如果 builder 仍然在构建 BrowserOS，说明 builder 当前工作树没有拿到这行改动。检查：

```bash
sed -n '112,119p' home/client-apps/packages.nix
git status --short
git log -1 --oneline
```

## 10. 尝试复用弱机器已有 BrowserOS store path

这次先查当前系统 closure，结果为空：

```bash
ssh root@192.168.3.237 'nix-store -qR /run/current-system | grep -i browseros' > /tmp/browseros-paths
cat /tmp/browseros-paths
```

没有输出说明当前系统 closure 里没有 BrowserOS。

再查整个弱机器 store：

```bash
ssh root@192.168.3.237 'find /nix/store -maxdepth 1 -iname "*browseros*" -print' > /tmp/browseros-paths
cat /tmp/browseros-paths
```

这次找到了弱机器已有 BrowserOS 路径，但它们和 builder 报错里需要的 `/nix/store/<hash>-browseros-0.46.0` hash 不同，所以不一定能复用。

复制时需要跳过签名检查：

```bash
xargs -r nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 < /tmp/browseros-paths
```

如果报：

```text
lacks a signature by a trusted key
```

说明忘了 `--no-check-sigs`，或者反方向复制时还需要信任目标 store。

## 11. Bitwarden keyctl 测试失败的处理

这次 Docker 构建 Bitwarden 时失败在测试：

```text
secure_memory::secure_key::keyctl::tests::test_is_supported ... FAILED
secure_memory::secure_key::keyctl::tests::test_multiple_keys ... FAILED
should get process keyring: Unknown(1)
```

原因：Docker/Nix build sandbox 里 process keyring 不可用，Bitwarden 的 keyctl 单元测试失败。这不是 Bitwarden 主程序编译失败。

本次临时处理：在 `overlays/50-general.nix` 覆盖 `bitwarden-desktop`，跳过 check：

```nix
bitwarden-desktop = prev.bitwarden-desktop.overrideAttrs (_old: {
  # The keyctl-based secure memory tests fail in Docker/Nix build sandboxes
  # where the process keyring is unavailable.
  doCheck = false;
});
```

同步这个改动后再继续 Docker build。

## 12. builder 和弱机器接力构建

如果 builder 已经编译了很多，但卡在 Docker/sandbox 特有问题，可以先把 builder 已完成的 store path 推给弱机器。

先确认两边配置树一致：

```bash
cd "$BUILDER_WORKDIR/nixos-config"
git rev-parse HEAD
git status --short
ssh root@192.168.3.237 'cd /etc/nixos && git rev-parse HEAD && git status --short'
```

把 builder 当前 store 中已经完成的非 `.drv` 路径批量推给弱机器：

```bash
nix path-info --all \
  | grep -v '\.drv$' \
  | xargs -r -n 200 nix copy --no-check-sigs --to 'ssh-ng://root@192.168.3.237?trusted=true'
```

如果还是签名报错，可以加：

```bash
--option require-sigs false
```

弱机器上用更短的 `nixos-rebuild build` 接力：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild build --flake .#ml-2700u -L --max-jobs 2 --cores 4
```

如果从 builder 远程触发：

```bash
ssh root@192.168.3.237 'cd /etc/nixos && export NIX_CONFIG="experimental-features = nix-command flakes" && nixos-rebuild build --flake .#ml-2700u -L --max-jobs 2 --cores 4'
```

弱机器 build 成功后，builder 拉回 result：

```bash
weak_result=$(ssh root@192.168.3.237 'readlink -f /etc/nixos/result')
nix copy --no-check-sigs --from ssh-ng://root@192.168.3.237 "$weak_result"
```

然后 builder 可以继续 build，或者直接推最终结果回弱机器。

## 13. builder 构建成功后推回弱机器

builder build 成功后会有：

```text
./result -> /nix/store/...-nixos-system-ml-2700u-...
```

推给弱机器：

```bash
nix copy --to ssh-ng://root@192.168.3.237 $(readlink -f result)
```

弱机器切换：

```bash
ssh root@192.168.3.237 'cd /etc/nixos && export NIX_CONFIG="experimental-features = nix-command flakes" && nixos-rebuild switch --flake .#ml-2700u -L'
```

如果弱机器本机已经 build 出了 `/etc/nixos/result`，也可以直接在弱机器上：

```bash
cd /etc/nixos
export NIX_CONFIG="experimental-features = nix-command flakes"
nixos-rebuild switch --flake .#ml-2700u -L
```

## 14. 这次经验总结

- Docker 空 `/nix` volume 会暴露弱机器已有 store path 掩盖掉的问题，例如 404、hash mismatch。
- 想复用 store path，配置树必须一致：同一 `HEAD`、同一 `flake.lock`、同一 dirty 内容。
- `nix copy --from` 远程 symlink 时，要先在远程 `readlink -f` 成真实 `/nix/store/...`。
- 弱机器本地 store 没有 binary cache 签名，点对点复制时需要 `--no-check-sigs`；作为 substituter 时需要 `--option require-sigs false`。
- 正在编译中的临时 build 目录不能复制；只能复制已经成功写入 `/nix/store` 的路径。
- 弱机器上 `nixos-rebuild build --flake .#ml-2700u -L --max-jobs 2 --cores 4` 比完整 `nix build .#nixosConfigurations...` 更短，更适合人工接力。
