# Hydra 构建链路与并发约束

本文是当前 Hydra 与 Nix 远程构建链路的权威说明。主机参数仍以
[`hosts/`](../../hosts) 为准；修改 builder 角色、并发或 feature 前必须同时更新
本文并按末尾流程回归。

## 不变量

- `ml-builder` 是唯一并行构建机（28 vCPU / 58 GiB），也是唯一声明 `big-parallel`
  的主机；并发上限 4、单任务 8 核，防止 2026-08-06 出现过的 OOM。
- `pve-5700u` 负责运行 Hydra 和虚拟机，只作为单任务 x86 回退节点。
- `opi5p` 首先是数据库、媒体和 reDroid 生产节点，只作为单任务原生 ARM 回退节点。
- `rock5c`、Router 和其他业务主机不加入 `nix-builder`；`ml-home-vm` 已退役。
- 构建派发图必须是有向无环图：PVE 可以派发到 ml-builder，ml-builder 不得反向派发
  到 PVE；ml-builder 只保留 OPI5P 作为原生 ARM 下游。
- `maxJobs` 限制同时运行的 derivation 数；`cores` 限制单个 derivation 获得的并行度。
  两者不能互相替代。

> 运行态告警（2026-08-03）：ml-builder 当前 `/etc/nix/machines` 仍包含
> `pve-5700u`，而 PVE 同时包含 `ml-builder`。这违反下面的目标拓扑，说明
> `excludeHosts = [ "pve-5700u" ]` 所在配置尚未在 ml-builder 的运行代际生效。
> 在重新部署并确认回边消失前，不能把当前构建链视为已经修复。

## 节点表

| 节点 | 地址 | 架构 | 同时任务 | 单任务核心 | speed factor | 声明 feature | 角色 |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `ml-builder` | `192.168.0.50` | `x86_64-linux` | 4 | 8 | 28 | `aarch64-cross`, `big-parallel` | 唯一主构建机，大包和交叉构建 |
| `pve-5700u` | `192.168.0.2` | `x86_64-linux` | 1 | 4 | 16 | 远程项无；Hydra localhost 有 `kvm,nixos-test,benchmark` | Hydra 调度、虚拟机宿主、x86 回退 |
| `opi5p` | `192.168.0.62` | `aarch64-linux` | 1 | 4 | 8 | 无 | 必须执行 ARM 目标程序时的原生回退 |

`speed factor` 只帮助 Nix 在同架构候选机之间排序，不是资源限制。真正的保护来自
`nixBuilder.maxJobs`、目标机 `nix.settings.max-jobs` 和 `nix.settings.cores`。

## 派发与缓存链路

| 阶段 | 来源 | 去向 | 选择依据 | 结果 |
| --- | --- | --- | --- | --- |
| 求值与排队 | Hydra（`pve-5700u`） | `/etc/nix/machines-with-localhost` | system、mandatory feature、可用槽位、speed factor | 选择实际 builder |
| 普通 x86 构建 | Hydra（PVE） | 优先 `ml-builder`，PVE localhost 单任务回退 | `x86_64-linux`，主机速度与槽位 | 构建输出进入 Nix store |
| ml-builder 本地发起 | ml-builder | x86 留在本机；原生 ARM 可到 `opi5p` | ml-builder 的机器表明确排除 PVE | 不产生 PVE↔ml-builder 回路 |
| 大型并行构建 | Hydra | 仅 `ml-builder` | derivation 要求 `big-parallel` | 不占用 PVE/OPI 业务资源 |
| ARM 交叉构建 | Hydra 或 ml-builder | `ml-builder` | build platform 仍是 x86，并要求 `aarch64-cross` | 生成 ARM 产物但不执行 ARM 二进制 |
| ARM 原生构建 | Hydra 或 ml-builder | `opi5p` | derivation 的 system 为 `aarch64-linux` | 单任务执行目标架构构建脚本 |
| 构建后上传 | Hydra RunCommand | `https://attic.zhyi.xin/lantian` | 成功输出路径 | 私有 Attic/S3 缓存 |
| 客户端取缓存 | Nix 客户端 | 先 Attic，再 `opi5p:13851` 的 NCPS | substituter 顺序 | NCPS 只代理公共上游，不反代 Attic |

Hydra 使用 `/etc/nix/machines-with-localhost`，因为它需要显式的 PVE localhost 项；普通
`nix build` 使用 `/etc/nix/machines`。不要把 localhost 写入普通远程 builder 文件，
否则 Nix daemon 可能在持有输出锁时把任务递归派回自己。

同理，不允许 PVE 与 ml-builder 互相出现在对方的派发链路中。2026-08-02 的实际故障中，
Hydra 从 PVE 把 derivation 交给 ml-builder 后，ml-builder 又把同一任务交回 PVE；两边
各自持有输出锁并等待对方，表现为构建永久停在 `waiting for lock`。因此
`ml-builder` 通过 `lantian.nix-distributed.excludeHosts = [ "pve-5700u" ];` 切断回边。
这是拓扑约束，不是临时性能调优，不能仅因 PVE 空闲就删除。

## 为什么必须这样限制

2026-08-02，OPI5P 曾同时被 ml-builder 与 PVE Hydra 当作 `maxJobs = 8`、
`big-parallel` 的 ARM builder。该机还在运行 PostgreSQL、媒体服务和 reDroid，结果：

- load average 峰值超过 140；
- `MemAvailable` 最低约 109 MiB；
- 内核在一次启动中记录 6 次 OOM；
- Java、PostgreSQL exporter、Samba、`nix-daemon` 和 `cc1plus` 被杀；
- 业务服务与 SSH 一并表现为“整机下线”。

问题不是 ARM 架构本身，也不是网线，而是同时 derivation 数与单 derivation 编译线程
叠乘。OPI5P 和 PVE 都承载常驻业务，因此宁可排队，也不能靠交换空间掩盖错误并发。

2026-08-06，ml-builder（28 vCPU / 58 GiB RAM）在 `maxJobs = 28`、`cores = 0` 下运行
Hydra 与本地构建，`nix-daemon` cgroup 内的多个 `cc1plus`/`cp` 触发全局 OOM，29 GiB
swap 一度用掉 16 GiB。ml-builder 专用于构建，但仍需要限制同时 derivation 数与单
derivation 线程数；当前声明与本地并发统一为 4，单任务最多 8 核。将来上调并发前，
先观察 `free -h`、swap 用量与 `journalctl -k | grep -i oom`。

## 变更与验收流程

1. 先停止 Hydra 派发：

   ```bash
   systemctl stop hydra-queue-runner.service
   ```

2. 修改目标主机的 `nixBuilder.maxJobs`；若该机也会本地构建，同时修改
   `nix.settings.max-jobs` 和 `nix.settings.cores`。
3. 先部署所有派发端（当前为 `ml-builder` 与 `pve-5700u`），再读取运行态文件：

   ```bash
   grep -E 'ml-builder|pve-5700u|opi5p' /etc/nix/machines
   grep -E 'ml-builder|pve-5700u|opi5p|localhost' /etc/nix/machines-with-localhost
   ```

   ml-builder 的第一条命令必须看不到 `pve-5700u`；PVE 的第二条命令应同时看到
   `ml-builder`、`opi5p` 与 `localhost`。若两端互相出现，禁止恢复 Hydra。

4. 用一个受控构建验证 OPI5P；期间检查：

   ```bash
   free -h
   cat /proc/loadavg
   journalctl -k -b --no-pager | grep -E 'Out of memory|Killed process'
   ```

   OPI5P 的可用内存低于 2 GiB、OOM 计数增加或出现多个并行编译 derivation 时立即停止
   派发并回滚配置。
5. 验证无误后恢复 `hydra-queue-runner`，再次确认实际机器表未回到高并发。

两个主机配置内还有 assertion：PVE 和 OPI5P 的声明并发与本地并发必须同时保持为 1。
因此将来上游合并若只改动其中一个值，求值会直接失败，而不是静默把生产节点重新变成
高并发 builder。
