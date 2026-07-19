# ml-home-vm 与 pve-5700u 复刻验收

本文记录 `ml-home-vm` 和 `pve-5700u` 对照作者配置后的实际结构与验收方法。
目标不是逐字复制作者的硬件地址，而是保留相同的角色、数据路径和服务关系。

## 作者映射

| 当前主机 | 作者主机 | 保留的角色 |
| --- | --- | --- |
| `ml-home-vm` | `lt-home-vm` | 家庭服务 VM、持久数据挂载、NCPS |
| `pve-5700u` | `pve-epyc` | PVE 虚拟化宿主、Hydra、远程构建调度 |

CPU 数量、磁盘设备、网卡名、MAC、城市、域名和局域网网段必须使用当前硬件的真实值，
不能复制作者环境中的值。`pve-5700u` 使用 Linux bridge `br0`，因为作者的
Open vSwitch 文件硬编码了作者机器的四张网卡。

## 当前链路

```text
Hydra (pve-5700u .54)
  |-- ARM/big-parallel --> ml-builder .50
  `-- native kvm/test --> Hydra localhost

Nix client
  |-- priority 5  --> Attic (colocrossing .52) --> S3
  `-- priority 10 --> NCPS (ml-home-vm .51) --> public caches

ml-home-vm /nix         --> pve-5700u VirtioFS
ml-home-vm /mnt/storage --> QNAP .93:/nixos (NFSv4.1)
```

局域网固定地址以 [home-lan-ip-plan.md](./home-lan-ip-plan.md) 为准。

## 应有运行状态

- `ml-home-vm` 的 `/nix` 来自 `virtiofs-nixos-home-vm`，`/mnt/storage` 来自
  `192.168.2.93:/nixos`。
- `ml-home-vm` 的 ZeroTier 为 `ONLINE`，`ltnet_colocrossing` 为 `Established`。
- Attic 的 `Priority` 小于 NCPS，且家庭客户端解析 Attic 与 VaultS3 时不应绕经公网。
- Hydra 成功完成系统任务后，通过 RunCommand 将构建结果上传到 Attic。

## 验收命令

在对应主机执行：

```bash
systemctl is-system-running
systemctl --failed
getent ahostsv4 attic.zhyi.xin vaults3.zhyi.cc
curl -fsS https://attic.zhyi.xin:8443/lantian/nix-cache-info
curl -fsS http://192.168.2.51:13851/nix-cache-info
```

在 `ml-home-vm` 继续检查：

```bash
findmnt --target /nix
findmnt --target /mnt/storage
zerotier-cli info
birdc show protocols | grep ltnet_colocrossing
```

在 `pve-5700u` 继续检查：

```bash
qm list
systemctl is-active hydra-evaluator hydra-queue-runner hydra-server
cat /etc/nix/machines-with-localhost
```

预期远程构建机表只包含 `ml-builder`。它声明 x86_64 和 ARM 平台，并支持
`big-parallel`；Hydra localhost 只声明非 ARM 平台，`ml-home-vm` 不参与构建。
这样 ARM 和大包都只交给强构建机。

## 保留事项

仓库中 PVE 的 LXC 兼容配置暂时保留，因为宿主机上仍有现存 CT。作者主要使用
声明式 QEMU VM，但在迁移或删除这些 CT 前，不能仅为了缩小 diff 移除兼容配置。

Hydra 日志中的 `step_finished` 参数警告不影响 `buildFinished` RunCommand；后者已由
Attic 中的实际系统闭包证明可用。除非上传链路本身失败，不应为这条非阻塞警告
偏离作者的 Hydra 模块结构。
