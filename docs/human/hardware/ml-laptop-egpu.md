# ml-laptop 雷电 eGPU（RTX 2080 Ti via TBT3 Oculink dock）适配记录

记录 2026-08-27 至 08-30 的完整排障过程：所有尝试、实测结果、已定罪与
已排除的根因，以及当前配置的三层防护和剩余问题。硬件同套在 Windows 下
稳定，Linux 侧问题均在软件栈。

## 硬件与拓扑

- 主机：HP 笔记本（Meteor Lake，JHL7440 雷电控制器），eGPU 经 TB3 隧道
- 坞：TBT4-Oculink DOCK eGPU PCIE（bolt uuid `bb030000-0070-7c0e-033f-e425de412825`），
  内置 Intel retimer（8087:d9c），GPU 插 Oculink 槽位
- 卡：RTX 2080 Ti（TU102，Turing，250W 默认 TDP，可调 100-280W）
- PCI 拓扑（由雷电拓扑决定，dock/USB-C 口不变则固定）：
  - `00:07.0` 根端口（CPU 侧，上行 2.5GT/s x4）
  - `02:00.0` / `03:01.0` / `03:02.0` / `03:04.0` 雷电桥 + 坞内交换芯片
  - `04:00.0` GPU 本体（.1 音频 / .2 USB xHCI / .3 UCSI 为姊妹功能）
- 关键事实：`_OSC` 显示 AER 控制权在固件，**所有链路级错误对内核不可见**，
  掉卡时 dmesg 只有 NVRM 三行（甚至完全没有）是常态，不代表没有链路错误
- 固件不持久化 thunderbolt authorized 状态：重启后 `authorized=0`，靠
  boltd boot ACL 自动重授权（`services.hardware.bolt.enable`）

## 相关提交时间线

| 提交 | 时间 | 内容 | 结果 |
| --- | --- | --- | --- |
| `ec9b4ea2` | 08-27 16:36 | eGPU 运行时休眠电源管理初版 | 方向正确，选项名用错 |
| `b3bb7211`/`29afa049` | 08-27 | leigod-accelerator 冲突排查 | 与 eGPU 无关 |
| `973e43b8` | 08-27 17:19 | TLP RUNTIME_PM_DENYLIST + udev（首次用对选项名） | ✅ Xid 154 消失 |
| `8b019d5a` | 08-27 17:50 | NVreg_DynamicPowerManagement=0 | ✅ 保留（RTD3 防护） |
| `f52e66d4` | 08-28 09:06 | 加 pci=realloc + pcie_aspm=off | ❌ realloc 致无法枚举 |
| `2e71ad30` | 08-28 09:32 | 回退 pci=realloc | — |
| `89ef6c3d` | 08-28 14:51 | 回退 pcie_aspm=off（JHL7440 不兼容） | ❌ |
| `47cf2eb7` | 08-28 15:44 | 降级驱动 595→535 | ⚠️ 后被撤销（见下） |
| `184075e7` | 08-29 15:15 | 排障收束：撤 535 降级、vfio.nix 按需注入、撤过滤器 | ✅ 根因修复 |
| `1e91e489` | 08-29 19:52 | egpu-clock-lock 核心锁频服务 | ✅ 降低触发概率 |
| (待提交) | 08-30 | lantian.kernel 换 6.12 LTS 对照 | 进行中 |

## 症状与根因（最终结论）

### 症状一：空载随机掉卡（Xid 79）——已根治

**根因：`pcie_acs_override=downstream,multifunction` 内核参数**。来自公共
模块 `nixos/hardware/vfio.nix`（经 `optional-apps/libvirt` 无条件引入），
在下游端口（含雷电桥）伪造 ACS、改写 PCIe 事务路由。该机无任何直通设备，
参数纯属死重；Windows 无此机制，是两系统最大差异之一。

修复（`184075e7`）：vfio.nix 改为**仅 `lantian.vfio.ids` 非空才注入**
这些参数。当前全 fleet 无主机配置直通设备，行为等价于"只对 ml-laptop
移除"，但未来做直通的主机配 ids 即自动恢复。

实证：移除前每次开机必死（595 下最快 3 分钟）；移除后空载全天稳定，
5h+ 零自发性掉卡。

### 症状二：游戏回落核显（DX12/DX11 不自动选 eGPU）——已根治

**根因：535 驱动的 Vulkan 缺 `VK_KHR_load_store_op_none`**，而 Proton
内置 DXVK 3.0.2 将其列为硬性要求，2080 Ti 被 DXVK 判为不合格
（`steam-1466860.log`: "Skipping: Device does not support required
feature 'khrLoadStoreOpNone'" → "No adapters found" → 游戏秒退或落核显）。
595 支持该扩展。

**教训**：535 降级（`47cf2eb7`）是为治症状一引入的错误修复——它从未
对症，只把首次掉卡从 3 分钟推迟到 1h43m，副作用是 DXVK 兼容性劣化。
已随 `184075e7` 撤销。游戏现在由 DXVK/VKD3D 默认策略（选最大显存设备）
自动落到 2080 Ti，无需任何过滤器或手动配置。

中途尝试过的 `DXVK_FILTER_DEVICE_NAME`/`VKD3D_FILTER_DEVICE_NAME`
会话级过滤器已撤销：535 缺扩展时过滤器只会让 DXVK 找不到任何设备。

### 症状三：游戏负载中掉卡（Xid 79/109）——已缓解，未根治

- **Xid 109（CTX SWITCH TIMEOUT）**：轻则崩溃当次游戏会话，卡可恢复
- **Xid 79 / 静默死**（配置空间全 0xFF，无任何日志）：整卡失联，
  软件无法救回

**根因：显存 reclocking（405↔7000MHz）瞬间的 TB3 隧道失联**。触发点
是游戏菜单/加载/退出的频率切换时刻。软件层手段全部实测：

| 手段 | 结果 |
| --- | --- |
| 限功 180W（`nvidia-smi -pl`） | ❌ 16 分钟即死，瞬时尖峰假说证伪 |
| 锁核心频率 1500MHz（`nvidia-smi -lgc`） | ⚠️ 有效降低：完整游戏会话从必死 → ~3.5h 一次 |
| 锁显存频率（`nvidia-smi -lmc`） | ❌ 驱动拒绝：TB3 下报 "Setting locked Memory clocks is not supported" |

锁核心已固化为 `egpu-clock-lock` oneshot 服务（`1e91e489`）：开机
`-pm 1` + `-lgc 1500,1500`，ConditionPathExists 与 CDI generator 同款
在位条件（坞未接自动跳过）。代价：帧率约 -10%，空载功耗 +10W。

静默死（08-30 02:39）证明锁频未根治：GPU 在无任何 Xid 的情况下从总线
消失。显存切换无法锁定，主机配置层面对此无解。

### 症状四：D3cold 唤醒失败（Xid 154）——已根治（08-27）

**根因：TLP `RUNTIME_PM_ON_AC=auto` 对隧道上所有 PCIe 设备启用运行时
PM**，.2 USB xHCI / .3 UCSI / 上游桥进入 D3cold 后经雷电线唤醒失败
（dmesg: "Unable to change power state from D3cold to D0, device
inaccessible"）。`finegrained=false` 只管 .0 功能的 RTD3，管不住 TLP
对其余功能的 PM。

修复（四层，全部保留）：
1. TLP `RUNTIME_PM_DENYLIST`：排除 eGPU 全部 4 功能 + 上游桥
   （注意：正确选项名是 `RUNTIME_PM_DENYLIST`，地址格式同 lspci 第一列
   不带 domain 前缀；此前用 `PCIE_RUNTIME_PM_DENYLIST` 是不存在的选项）
2. udev 规则强制 `power/control=on`（KERNEL 用 sysfs 全名带 `0000:`，
   兜底防 nvidia bind 规则改回 auto）
3. `NVreg_DynamicPowerManagement=0`（关驱动内部 RTD3）
4. `hardware.nvidia.powerManagement.finegrained = mkForce false`

## 排障过程中的重要教训

1. **不要在 RM 运行时改 GPU 端点（04:00.0）的 DevCtl2**：NVIDIA RM 自己
   管理该寄存器，运行时改完 RmInitAdapter 全灭（0x22:0x56:774，此错误码
   历史仅出现于该次），只能坞断电重来。根端口（00:07.0）可安全改。
2. **掉线后软件无法恢复**：PCI remove/rescan 实测无效（function 0 不再
   枚举回来），无论配置空间全 0xFF 还是 RM 初始化失败形态。唯一恢复
   手段：坞断电重插，或整机重启。
3. **AER 不可见**：_OSC 未授予 OS，链路错误全被固件吞掉；"无 AER 错误"
   不能作为排除链路问题的证据。
4. **一次性单变量实验**：多个"修复"叠加会互相污染归因（535 降级 + ACS
   移除同时生效时，掉卡暂时消失导致 535 被误判有效）。回滚要成对进行。
5. **部署路径**：Mac 不是部署机。rsync 工作区到 ml-builder `/root/nixos-config`
   → `nix run .#colmena -- apply --on <host>`。仓库自带 colmena 仅
   x86_64-linux 可跑，且需要 `--impure`。

## 已排除的假说（避免重复排查）

| 假说 | 排除方式 |
| --- | --- |
| CTO 完成超时 | 根端口 00:07.0 禁用（DevCtl2 TimeoutDis+）后 3 分钟仍掉 |
| 坞内交换芯片 DevCtl2 | 只读，setpci 写不进（绝对偏移 0xe8 同样只读） |
| 硬件供电/卡本体 | Windows 同套硬件零故障（含重载游戏） |
| GSP 固件 | /proc 确认 N/A（已加载参数关闭），仍掉 |
| ASPM | FADT 声明不支持，系统本就未启用；强制 off 反致 JHL7440 异常 |
| IOMMU/DMAR | intel_iommu=on + iommu=pt 下零 DMAR fault 记录 |
| pci=realloc | 雷电桥 memory window 不分配，eGPU 无法枚举 |

## 当前状态与后续选项

配置三层防护（全部已部署，见 `hosts/ml-laptop/configuration.nix`）：
ACS 移除（项目级 vfio.nix 按需注入）+ egpu-clock-lock 核心锁频 +
D3cold 四层防护。残余：重度游戏日约 1-2 次掉卡，恢复 = 整机重启
（或坞断电），全程约 2 分钟。

进行中：`lantian.kernel = linux_6_12` 内核对照（排除 CachyOS 6.18
thunderbolt 栈回归；NVIDIA 官方支持矩阵钉 6.12）。判定：6.12 下完整
游戏会话不掉 → 保持覆写；仍掉 → 恢复默认内核，转以下选项：

1. 换 Intel 认证 0.5m TB3 短线（链路误码会放大 reclocking 瞬间失联；
   枚举时出现过 `DROM data CRC32 mismatch`）
2. 坞固件更新（TBT4-Oculink 方案固件迭代频繁；retimer 8087:d9c）
3. 向 NVIDIA open-gpu-kernel-modules 报 TB3 + Turing reclocking issue

关联：Discord 等 Chromium 应用的 Vulkan 视频管线会主动选中 eGPU 加重
触发（线程 `[vkps] Update`），建议在 Discord 设置中关闭硬件加速（GUI
操作，未纳入配置）。
