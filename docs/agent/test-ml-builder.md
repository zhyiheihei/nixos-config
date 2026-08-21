# ml-builder 验收与排障

`ml-builder` 是当前强构建机，主机元数据在
[`hosts/ml-builder/host.nix`](../../hosts/ml-builder/host.nix)。它的部署地址为
`ml-builder.zhyi.xin`，SSH 使用端口 `2222`，局域网固定地址以
[家庭局域网 IP 规划](home-lan-ip-plan.md) 为准。

## 连接与基础状态

从管理机连接：

```bash
ssh -A -p 2222 root@ml-builder.zhyi.xin
```

登录后执行：

```bash
hostnamectl
systemctl is-system-running
systemctl --failed
nproc
nix show-config | grep -E '^(max-jobs|cores) ='
df -h /nix
```

期望系统为 `running`、没有 failed unit，且 CPU 线程数与 `host.nix` 的
`cpuThreads` 相符；`nix show-config` 的 `max-jobs`/`cores` 应为 1 / 0。
重装或 SSH host key 变化后，先更新本机 known_hosts 与
`hosts/ml-builder/host.nix` 的 `ssh.ed25519`，再运行 Colmena。

## 缓存与 Git

```bash
cd /nix/src/nixos-config
git pull --ff-only

nix show-config | grep -E '^(substituters|trusted-public-keys) ='
curl -fsS https://attic.zhyi.xin/lantian/nix-cache-info
```

缓存 URL 和公钥以 `helpers/constants/nix.nix` 为准。若 Attic 不可达，先检查
DNS、到 greencloud 的局域网覆盖及服务端状态，不要临时关闭签名校验。

## 构建验收

先只构建自身配置：

```bash
nix build .#nixosConfigurations.ml-builder.config.system.build.toplevel -L
```

再验证 `hosts/` 中的完整自有 Hive，但不切换：

```bash
make build
```

`make all` 和 `make servers` 会部署对应 Colmena 标签，不能作为单机测试命令。完整说明见
[构建与部署](deployment.md)。

## 内存与 OOM 排障

`ml-builder` 的物理内存约 58 GiB，zram 已配置为 100%（约 58 GiB swap），
`max-jobs = 1`、`cores = 0`。并发上限防止多个大包同时编译，但管不住单个进程
的内存峰值：例如 Firefox 的 `ld.lld` 链接阶段 RSS 可达 25-30 GiB，
2026-08-07 曾因此被内核 OOM killer 杀掉。

验证当前内存配置：

```bash
swapon --show
zramctl
journalctl -k --since "24 hours ago" | rg -i 'oom|ld.lld|killed process'
```

若再次 OOM，先看内核日志中被杀的是不是单个 `ld.lld`/`cc1plus`，再决定是否
降低并发或检查 zram；不要为了提速直接调大 `max-jobs`。

## 作为远程 builder

Hydra/PVE 通过 `nix-builder@ml-builder.zhyi.xin` 使用该机。连接失败时，在调度机
检查：

```bash
ssh -A -p 2222 nix-builder@ml-builder.zhyi.xin true
cat /etc/nix/machines-with-localhost
```

再检查 builder 本机的 `nix-builder` 用户和 SSH 授权配置。不要为了临时测试而把
`root`、`nix-builder` 或任意 Bitwarden agent key 批量加入远程主机。
