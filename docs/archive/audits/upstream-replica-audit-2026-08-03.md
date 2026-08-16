# 2026-08-03 作者配置复刻偏移审计

## 审计结论

当前仓库仍保留了作者项目的主体结构，并不是已经分叉成另一套独立设计：

- `nixos/minimal.nix`、`nixos/server.nix`、`nixos/pve.nix` 与作者一致；
- impermanence、Nginx hosts 生成、Hydra `post-build.py`、socket-activated
  iperf 等关键实现与作者一致；
- 主机模型、模块自动导入、`LT` 辅助集和标签体系仍沿用作者框架。

本次审计确认了 **2 项明确遗漏，并已在同一轮对齐中处理**：

1. 作者已经删除 `nix-cache-proxy`，本仓库仍保留 input、overlay、模块和端口；
2. 作者已经把一组公开 Nginx 虚拟主机限制到 `public-facing` 主机，本仓库仍有
   无条件启用和继续依赖已废弃 `low-disk` 标签的实现。

其余主要差异来自本地主机、ARM 硬件、私有域名、缓存、备份和定向构建拓扑。
这些差异大多有实际运行需求，不应该通过整目录覆盖作者仓库来消除。正确方向是：
**公共模块默认行为跟作者，本地拓扑通过参数或目标主机配置表达。**

## 审计范围与基准

| 项目 | 审计值 |
| --- | --- |
| 本仓库提交 | `2f378e52ee28743d22bf5e14350b1cf218330f11` |
| 本仓库远端提交 | `5c6a47d51258e0f3cd80ed44b69d70a69401b618` |
| 作者仓库 | `../nixos-config-exam` |
| 作者提交 | `6a9e45a3c978bb3e85abde4e5635c83bf763ec46` |
| 作者提交时间 | 2026-07-30 |
| 审计时间 | 2026-08-03 |

审计覆盖 `flake-modules/`、`helpers/`、`home/`、`nixos/`、`overlays/`、
`patches/`、`pkgs/`、`dns/`、`hosts/`、`Makefile` 和近期运行验收结果。

审计时工作区已有未提交的 LubanCat 与 `flake.lock` 修改，以及 `.reasonix/`。这些
属于正在进行的用户工作，本次没有改动，也没有把它们计入已提交基线结论。

## 规模对比

### 文件数量

| 目录 | 本仓库 | 作者仓库 | 说明 |
| --- | ---: | ---: | --- |
| `flake-modules/` | 13 | 13 | 框架完整 |
| `helpers/` | 31 | 31 | 框架完整，常量值存在本地化 |
| `home/` | 54 | 54 | 文件集合完整 |
| `nixos/` | 486 | 454 | 多出 ARM 硬件和本地服务模块 |
| `overlays/` | 11 | 8 | 多出 3 个本地 overlay |
| `patches/` | 34 | 35 | 总量接近 |
| `pkgs/` | 51 | 46 | 多出 5 个本地包 |
| `dns/` | 20 | 27 | 域名与区域数据是本地资产 |
| `hosts/` | 63 | 96 | 主机清单不同，不能按文件数强行对齐 |
| `docs/` | 50 | 0 | 本仓库维护自己的运维文档 |

### 公共 Nix 文件一致度

对上述公共目录中两边同路径的 Nix 文件进行逐文件比较：

- 共同文件：472 个；
- 完全一致：266 个；
- 内容不同：206 个。

其中差异最多的是 `nixos/`：共同文件中 280 个一致、172 个不同；本仓库另有
34 个 NixOS 模块。数量本身不等于问题，域名、地址、凭据接口和主机拓扑会产生
大量合理差异，因此必须按语义分类。

## 已确认与作者一致的关键骨架

| 范围 | 状态 | 结论 |
| --- | --- | --- |
| `nixos/minimal.nix` | 一致 | 最小角色的模块组合未偏移 |
| `nixos/server.nix` | 一致 | 服务器角色的模块组合未偏移 |
| `nixos/pve.nix` | 一致 | PVE 角色入口未偏移 |
| `nixos/minimal-components/impermanence.nix` | 一致 | tmpfs `/` 与持久化体系沿用作者模式 |
| `nixos/common-apps/nginx/hosts.nix` | 一致 | hosts 生成逻辑未私改 |
| `nixos/common-apps/nginx/proxy.nix` | 一致 | Nginx 代理总开关已经使用 `server && public-facing` |
| `nixos/optional-apps/hydra/post-build.py` | 一致 | Hydra 后处理逻辑没有形成私有分支 |
| `nixos/server-apps/iperf.nix` | 一致 | 已吸收作者的 socket activation 改动 |

这说明后续应继续做小范围语义同步，不需要重建仓库结构或重新复制作者项目。

## 本次已经处理的偏差

### 已处理：恢复公开 Nginx 服务的 `public-facing` 边界

作者在 `0f750d89` 中把多项公开虚拟主机限制为仅在 `public-facing` 主机启用，
随后在 `07c18751` 中移除了 `low-disk` 标签。本次已经吸收这两项修改。

对齐前确认的问题是：

- `autoconfig.nix`、`libravatar.nix`、`testssl.nix`、
  `vhost-hydra-proxy.nix`、`whois-server.nix` 等缺少作者的
  `public-facing` 条件；
- `vhost-matrix-element/`、`vhost-tools/`、`vhost-um/` 仍依赖
  `!low-disk`；
- `low-disk` 仍存在于标签常量以及 `volcengine`、`hostdare`、`google`；
- 本地只有 `volcengine`、`hostdare`、`google`、`greencloud` 标记为
  `public-facing`，内网的 `ml-builder`、`ml-home-vm`、`opi5p`、
  `rock5c` 等不应自动承载这些公开站点。

风险包括：内网主机闭包膨胀、无意义证书或后端依赖、额外监听和服务暴露，以及
不同角色之间的 Nginx 配置冲突。

实际处理保持了本地域名和真正需要公开的主机标签，只同步作者的条件语义：公开
站点由 `public-facing` 控制，`vhost-um` 按作者保持私有站点的无条件声明，
`low-disk` 标签及三台主机上的引用已经删除。

### 已处理：跟随作者删除 `nix-cache-proxy`

作者在 `6a9e45a3` 中完整删除了该组件。对齐前本仓库仍保留：

- `flake.nix` 中的 `nix-cache-proxy` input；
- `flake-modules/nixos-configurations.nix` 中的 NixOS module；
- `flake-modules/nixpkgs-options.nix` 中的 overlay；
- `flake.lock` 节点；
- `helpers/constants/ports.nix` 端口；
- `nixos/minimal-components/nix-cache-proxy.nix`；
- `nixos/optional-apps/ncps-client.nix` 中强制禁用它的遗留行。

当前实际缓存链路已经使用私有 Attic 与 OPI5P NCPS，因此保留一个被强制禁用、
作者也已移除的实现没有收益，只会增加 input、求值和维护成本。

本次已经删除上述 input、overlay、模块、端口和 lock 引用，同时保留 `flake.lock`
中正在进行的 LubanCat/secrets 更新，没有用作者锁文件覆盖本地输入。

### 已处理：Hydra 输出跟随作者

作者在 `4df34856` 后将 Hydra 输出定义为：

- `apps`；
- `packages`；
- `devShells`；
- 全部 `nixosConfigurations`。

本仓库原先只导出 `packages` 和 6 台 x86 NixOS 主机。现已按作者改为导出
`apps`、`packages`、`devShells` 和全部 `nixosConfigurations`。

ARM 内核体积、交叉编译成本和低并发 builder 约束仍由既有构建机特性、并发和
定向 builder 图控制，不再通过缩减 Hydra 输出隐藏主机配置。

### 已处理：恢复作者的 `nix-cache-attic` 模块导入

作者在 `flake-modules/nixos-configurations.nix` 中导入：

```nix
inputs.nur-xddxdd.nixosModules.nix-cache-attic
```

本次已经删除相同位置的 `nix-cache-proxy` 导入，并恢复作者的
`nix-cache-attic` 模块。私有 Attic 的地址、netrc、签名 key 和上传授权仍使用
本地配置；主机求值用于确认两者没有选项冲突。

### P2：公共模块中的本地拓扑改动需要保持参数化

以下差异有生产依据，但长期应确保作者默认行为仍可辨认：

| 模块 | 本地差异 | 审计意见 |
| --- | --- | --- |
| `nix-distributed.nix` | 按主机设置并发、特性、排除反向委派 | 必须保留；已有构建链路文档 |
| `hydra/default.nix` | 本地凭据、Attic 上传、队列 key | 必须保留；凭据只从 SOPS 注入 |
| `ncps.nix` / `ncps-client.nix` | 私有 Attic 优先、OPI5P NCPS、存储参数 | 必须保留；删除旧 proxy 后重新审视公共默认值 |
| `backup/` | 本地 SFTP endpoint 与 SOPS 顺序 | 必须保留；继续使用参数而非硬编码主机判断 |
| `coredns.nix` | 国内 DNS、LTNET 和 NetworkManager 顺序 | 本地网络必需；保留 |
| `ssh-harden.nix` | 本地域名、用户和 `/var/empty` 启动前处理 | 前两项必需；最后一项应确认能否缩小到受影响主机 |
| `client.nix` | `stylix.autoEnable = true` | 低风险，但应记录其必要性 |

审计原则不是禁止修改公共模块，而是要求公共模块提供参数和合理默认值，具体地址、
存储路径、并发与主机关系由 `host.nix` 或目标主机配置传入。

## 明确应保留的本地差异

以下内容属于复刻环境的身份和硬件边界，不应向作者值回退：

1. `hosts/` 中的本地主机名称、地址、SSH key、城市和标签；
2. `dns/` 中的 `zhyi.xin`、`zhyi.cc`、`moliy.site` 及服务记录；
3. SOPS recipient、私有凭据和本地 secrets 仓库；
4. NanoPi R5C、Orange Pi 5 Plus、Rock 5C、LubanCat、H28K 等 ARM 硬件模块；
5. Rockchip 内核、设备树、U-Boot、reDroid、风扇和存储适配；
6. 私有 Attic、NCPS、VaultS3、NAS 与家庭网络路由；
7. ml-builder、pve-5700u、opi5p 的定向构建图和资源权重；
8. 本地备份 endpoint、国内外 DNS 分流和跨主机服务分配。

这些差异应通过小模块、参数和主机配置隔离，不应反向修改作者仓库，也不应为了
减少 diff 而删除已经验收的生产能力。

## 运行态回归证据

本次审计同时参考了近期完成的运行验收：

- VaultS3 当前链路为
  `客户端 :8443 -> Router DNAT/回流 -> OPI5P nginx :443 -> NAS :9000`；
- OPI5P 只在标准 HTTPS 端口 443 提供入口，Router 负责外部 8443 映射；
- VOLCENGINE 与 ml-builder 均可从最终 Attic NAR 地址取得相同的 HTTP 200 内容；
- Router、OPI5P、VOLCENGINE 相关服务均处于 active，无 failed unit；
- Hydra 的构建委派方向已验证为 PVE/Hydra 到 ml-builder/OPI，未出现反向递归；
- OPI5P 历史 OOM 计数未继续增长，ARM builder 已降低并发；
- Rock 5C 的 reDroid、MetaCubeXD 与备份链路已通过运行检查。

这些结果证明私有网络、缓存和 ARM 差异并非无依据的代码膨胀；同步作者时必须保留
已经验证的拓扑行为。

## 验证缺口

本次以只读静态比较和既有运行验收为主，没有在含未提交 `flake.lock`/LubanCat
改动的工作区执行全量构建。此前全局 `nix flake check --no-build` 曾在 DNS SSHFP
的 import-from-derivation 路径上失败，而目标主机逐一求值成功。该问题应作为全局
验收缺口单独解决，不能用单台部署成功代替整个仓库的 CI 检查。

## 推荐执行顺序

1. 在 Linux 构建机求值公开主机 `greencloud` 和内网主机 `opi5p`；
2. 比较两台主机生成的 Nginx vhost，确认公开站点边界；
3. 检查私有 Attic、NCPS 的 substituter 与 trusted key 没有被作者模块覆盖；
4. 逐台运行 NixOS 配置求值，最后再运行全局 `nix flake check`；
5. 部署时先 canary，再扩展到 `make all`，并复查 failed units、端口与缓存命中。

## 后续同步守则

- 每次同步先记录作者基准提交，再查看作者自上次审计后的提交列表；
- 公共模块的删除、接口变化、安全边界和弃用修复优先跟随作者；
- hosts、硬件、域名、IP、证书、secrets 和生产拓扑禁止机械覆盖；
- 新增公共差异时优先设计参数，避免出现 `hostname == ...` 式散落判断；
- 每项保留差异都要能指出运行需求、目标主机和验证方法；
- ARM 镜像成功不等于部署配置成功，部署成功也不等于冷启动和服务链路成功；
- 旧审计只反映当时基线，当前判断以本文和实际配置为准。

## 相关文档

- [2026-07-28 上游对齐偏差审计](upstream-alignment-audit-2026-07-28.md)
- [Hydra 构建链路与并发约束](../../agent/hydra-build-chain.md)
- [自建 Attic + S3 构建缓存](../../agent/attic-s3-cache.md)
- [域名与服务编排](../../agent/domain-service-layout.md)
- [ARM 开发板 NixOS 适配手册](../../human/hardware/arm-board-bring-up.md)
