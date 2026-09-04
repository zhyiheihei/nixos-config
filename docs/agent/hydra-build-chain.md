# Hydra 构建链路与并发约束

本文是当前 Hydra 与 Nix 远程构建链路的权威说明。主机参数仍以
[`hosts/`](../../hosts) 为准；修改 builder 角色、并发或 feature 前必须同时更新
本文并按末尾流程回归。

## 不变量

- **2026-09-04 起 Hydra 跑在 `ml-laptop`**（自 ml-builder 迁入，见下文
  「构建拓扑」），公共 vhost `hydra.zhyi.xin` 在 greencloud 覆写后端指向
  ml-laptop 的 LTNET 地址。
- `ml-builder` 仍是唯一主构建机（28 vCPU / 58 GiB），也是唯一声明
  `big-parallel` 的主机；同时只跑 1 个 derivation，单任务不限核数
  （`cores = 0`），防止 2026-08-06 出现过的多任务 OOM。Hydra 迁走后本机
  回归纯构建机定位（archiveteam/clawemail/epic 容器同期迁出）。
- `pve-5700u` 是纯 Proxmox VE 宿主，不再运行 Hydra，也不再作为 Nix 回退 builder。
- `opi5p` 首先是数据库、媒体和 reDroid 生产节点，只作为单任务原生 ARM 回退节点。
- `rock5c`、Router 和其他业务主机不加入 `nix-builder`；`ml-home-vm` 已退役。
- 构建派发图必须是有向无环图：派发表排除 PVE，保留 OPI5P 作为原生 ARM
  下游，QEMU 只作远程构建关闭时的回退。PVE 不参与任何构建派发。
- `maxJobs` 限制同时运行的 derivation 数；`cores` 限制单个 derivation 获得的
  并行度。两者不能互相替代。

## 构建拓扑（2026-09-04 定稿，Hydra on ml-laptop）

- **ml-laptop 保留 1 个本地构建槽**（`nix.settings.max-jobs = 1`）：吸收
  小构建与求值期 FOD，避免 builder 网络抖动时全部外派空转。
- **ml-laptop 不打 `nix-builder` 标签**：不对外通告本机为集群构建机，其他
  主机的分布式构建不派发到这台笔记本。
- ml-laptop 的 `/etc/nix/machines`（由 `nix.buildMachines` 生成）仅含远端：
  ml-builder 条目额外通告 `aarch64-cross`——ARM 厂商内核交叉构建带
  `requiredSystemFeatures = [ "aarch64-cross" ]` 硬性要求，不通告则
  max-jobs 外无机器可接、直接失败；opi5p 条目承接 aarch64 原生构建。
  Hydra 与本机 daemon 共用这一份机器清单。
- ml-builder 侧以 `nix.settings.extra-system-features = [ "aarch64-cross" ]`
  声明同款 feature，本地可跑交叉构建；ml-laptop 本地 daemon 也声明该
  feature（四个 ARM 硬件内核包带 requiredSystemFeatures）。
- ml-laptop 的 hydra-evaluator unit 注入集群出站代理（直连 GitHub 拉
  flake inputs 实测长期卡死），见 [outbound-proxy](outbound-proxy.md)。
- Hydra 已从 ml-builder 撤除；`secrets/hydra.yaml` 的
  `hydra-builder-ssh-privkey` 仍是 `nix-distributed` 到各构建机的 SSH 凭据，
  ml-builder 继续布线。

## 节点表

| 节点 | 地址 | 架构 | 同时任务 | 单任务核心 | speed factor | 声明 feature | 角色 |
| --- | --- | --- | ---: | ---: | ---: | --- | --- |
| `ml-builder` | `192.168.0.50` | `x86_64-linux` | 1 | 0（默认全核） | 28 | `aarch64-cross`, `big-parallel`；Hydra localhost 另有 `kvm,nixos-test,benchmark` | 唯一主构建机，大包和交叉构建 |
| `opi5p` | `192.168.0.62` | `aarch64-linux` | 1 | 0（默认全核） | 8 | 无 | 必须执行 ARM 目标程序时的原生回退 |
| `ml-laptop` | `192.168.0.55` | `x86_64-linux` | 1（仅本机） | — | — | `aarch64-cross`（本地 daemon） | Hydra 所在地；吸收小构建与求值期 FOD，不对外通告 |

`speed factor` 只帮助 Nix 在同架构候选机之间排序，不是资源限制。真正的保护来自
`nixBuilder.maxJobs`、目标机 `nix.settings.max-jobs` 和 `nix.settings.cores`。

## 派发与缓存链路

| 阶段 | 来源 | 去向 | 选择依据 | 结果 |
| --- | --- | --- | --- | --- |
| 求值与排队 | Hydra（`ml-builder`） | `/etc/nix/machines-with-localhost` | system、mandatory feature、可用槽位、speed factor | 选择实际 builder |
| 普通 x86 构建 | Hydra | `ml-builder` localhost 单任务 | `x86_64-linux`，主机速度与槽位 | 构建输出进入 Nix store |
| ml-builder 本地发起 | ml-builder | x86 留在本机；原生 ARM 到 opi5p，QEMU 回退 | ml-builder 的机器表排除 PVE，保留 OPI5P | 不产生 PVE↔ml-builder 回路 |
| 大型并行构建 | Hydra | `ml-builder` localhost | derivation 要求 `big-parallel` | 不占用 PVE/OPI 业务资源 |
| ARM 交叉构建 | Hydra 或 ml-builder | `ml-builder` | build platform 仍是 x86，并要求 `aarch64-cross` | 生成 ARM 产物但不执行 ARM 二进制 |
| ARM 原生构建 | Hydra 或 ml-builder | `opi5p` | derivation 的 system 为 `aarch64-linux` | 单任务执行目标架构构建脚本 |
| 构建后上传 | Hydra RunCommand | `https://attic.zhyi.xin/zhyi` | 成功输出路径 | 私有 Attic/S3 缓存 |
| 客户端取缓存 | Nix 客户端 | 先 Attic，再 `opi5p:13851` 的 NCPS | substituter 顺序 | NCPS 只代理公共上游，不反代 Attic |

Hydra 使用 `/etc/nix/machines-with-localhost`，因为它需要显式的 ml-builder localhost
项；普通 `nix build` 使用 `/etc/nix/machines`。不要把 localhost 写入普通远程 builder
文件，否则 Nix daemon 可能在持有输出锁时把任务递归派回自己。

2026-08-02 的实际故障中，Hydra 从 PVE 把 derivation 交给 ml-builder 后，ml-builder
又把同一任务交回 PVE；两边各自持有输出锁并等待对方，表现为构建永久停在
`waiting for lock`。因此 `ml-builder` 通过
`lantian.nix-distributed.excludeHosts = [ "pve-5700u" ];` 切断回边，并且 pve-5700u
不再声明 `nix-builder` 标签。这是拓扑约束，不是临时性能调优。

## 为什么必须这样限制

2026-08-02，OPI5P 曾同时被 ml-builder 与 PVE 上的 Hydra 当作 `maxJobs = 8`、
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
swap 一度用掉 16 GiB。ml-builder 专用于构建，但仍需要限制同时 derivation 数；
当前声明与本地并发统一为 1，单任务不限核数（`cores = 0`）。将来上调并发前，
先观察 `free -h`、swap 用量与 `journalctl -k | grep -i oom`。

## 变更与验收流程

1. 先停止 Hydra 派发：

   ```bash
   systemctl stop hydra-queue-runner.service
   ```

2. 修改目标主机的 `nixBuilder.maxJobs`；若该机也会本地构建，同时修改
   `nix.settings.max-jobs` 和 `nix.settings.cores`。
3. 先部署所有派发端（当前为 `ml-builder`），再读取运行态文件：

   ```bash
   grep -E 'ml-builder|pve-5700u|opi5p' /etc/nix/machines
   grep -E 'ml-builder|pve-5700u|opi5p|localhost' /etc/nix/machines-with-localhost
   ```

   ml-builder 的两条命令都必须看不到 `pve-5700u`；`machines-with-localhost` 应同时
   看到 `opi5p` 与 `localhost`。PVE 上不应再存在 `/etc/nix/machines*` 构建派发表。

4. 用一个受控构建验证 OPI5P；期间检查：

   ```bash
   free -h
   cat /proc/loadavg
   journalctl -k -b --no-pager | grep -E 'Out of memory|Killed process'
   ```

   OPI5P 的可用内存低于 2 GiB、OOM 计数增加或出现多个并行编译 derivation 时立即停止
   派发并回滚配置。
5. 验证无误后恢复 `hydra-queue-runner`，再次确认实际机器表未回到高并发。

ml-builder 与 OPI5P 的配置内还有 assertion：声明并发与本地并发必须同时保持为 1。
因此将来上游合并若只改动其中一个值，求值会直接失败，而不是静默把生产节点重新变成
高并发 builder。
