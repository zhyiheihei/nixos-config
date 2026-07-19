# ml-builder 验收与排障

`ml-builder` 是当前强构建机，主机元数据在
[`hosts/ml-builder/host.nix`](../hosts/ml-builder/host.nix)。它的部署地址为
`ml-builder.zhyi.cc`，SSH 使用端口 `2222`，局域网固定地址以
[家庭局域网 IP 规划](./home-lan-ip-plan.md) 为准。

## 连接与基础状态

从管理机连接：

```bash
ssh -A -p 2222 root@ml-builder.zhyi.cc
```

登录后执行：

```bash
hostnamectl
systemctl is-system-running
systemctl --failed
nproc
df -h /nix
```

期望系统为 `running`、没有 failed unit，且 CPU 线程数与 `host.nix` 的
`cpuThreads` 相符。重装或 SSH host key 变化后，先更新本机 known_hosts 与
`hosts/ml-builder/host.nix` 的 `ssh.ed25519`，再运行 Colmena。

## 缓存与 Git

```bash
cd /nix/src/nixos-config
git pull --ff-only

nix show-config | grep -E '^(substituters|trusted-public-keys) ='
curl -fsS https://attic.zhyi.xin:8443/lantian/nix-cache-info
```

缓存 URL 和公钥以 `helpers/constants/nix.nix` 为准。若 Attic 不可达，先检查
DNS、到 colocrossing 的局域网覆盖及服务端状态，不要临时关闭签名校验。

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
[构建与部署](./deployment.md)。

## 作为远程 builder

Hydra/PVE 通过 `nix-builder@ml-builder.zhyi.cc` 使用该机。连接失败时，在调度机
检查：

```bash
ssh -A -p 2222 nix-builder@ml-builder.zhyi.cc true
cat /etc/nix/machines-with-localhost
```

再检查 builder 本机的 `nix-builder` 用户和 SSH 授权配置。不要为了临时测试而把
`root`、`nix-builder` 或任意 Bitwarden agent key 批量加入远程主机。
