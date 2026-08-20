# 文档索引

配置的最终来源始终是 `hosts/`、`nixos/`、`helpers/`、`dns/` 与 `Makefile`。
本文档只记录当前操作约束、架构解释和经验证的迁移记录。

**docs/ 按读者分为两大类，另有归档区**：

| 目录 | 读者 | 内容 |
| --- | --- | --- |
| [`agent/`](agent/README.md) | agent（执行规范） | 本仓库 agent 必须遵守的规范、操作手册与参照；干活前必读 |
| [`human/`](human/README.md) | 人（指南与记录） | 入门、服务指南、硬件适配、调研、学习笔记、迁移记录；agent 需用时也读 |
| [`archive/`](archive/README.md) | 无（历史归档） | 过时/已完成的历史记录，不作为当前操作依据 |

划分规则：**agent 干活要执行/遵守的 → `agent/`；给人看的使用指南与历史记录 → `human/`；
过时/已完成、不再作为当前依据的 → `archive/`。**

## 给 agent 看（docs/agent/）

见 [`agent/README.md`](agent/README.md)：工作规范、skill 使用、AI 网关链路、模块分层、
主机清单、新主机接入、开发手册、部署/巡检/重装、主题规范与参照。

## 给人看（docs/human/）

### 入门

- [适配自己的 NixOS 设备](human/getting-started/adapt-own-device.md)
- [客户端设备入网指南](human/getting-started/client-device-onboarding.md)
- [非 NixOS 设备加入知识链](human/getting-started/non-nixos-knowledge-chain.md)

### 硬件适配

- [ARM 开发板 NixOS 适配手册](human/hardware/arm-board-bring-up.md)
- [HINLINK H28K（RK3528）NixOS 路由器适配](human/hardware/hinlink-h28k.md)
- [LubanCat 1 适配](human/hardware/lubancat-1.md)
- [NanoPi R5C NixOS 镜像适配与安装](human/hardware/nanopi-r5c.md)
- [NanoPi R5C 内核与系统闭包裁剪审计](human/hardware/nanopi-r5c-size-audit.md)
- [NanoPi R5C：从 macOS 写入 SD 卡到读取串口日志](human/hardware/nanopi-r5c-flash-and-serial.md)
- [Orange Pi 5 Plus reDroid 适配](human/hardware/orangepi-5-plus-redroid.md)
- [Radxa Rock 5C 适配](human/hardware/radxa-rock-5c.md)
- [腾讯云 VPS 适配](human/hardware/tencent-cloud-vps.md)
- [Mac mini（nix-darwin）接入与维护](human/hardware/macmini.md)

### 网络

- [LTNET 家庭中继与缓存链路](human/network/ltnet-home-relay.md)
- [分地区 DNS 方案](human/network/regional-dns.md)
- [DN42 当前拓扑](human/network/dn42.md)
- [Flclash 家庭拓扑与覆盖配置](human/network/flclash-home-topology.md)
  （覆盖文件 [flclash-home-override.yaml](human/network/flclash-home-override.yaml)）

### 基础设施

- [AI 链 ↔ 知识链整合](human/infrastructure/ai-knowledge-chain-integration.md)

### 服务指南

- [Homepage 卡片与健康检查](human/services/homepage-link-audit.md)
- [下载与媒体链路使用指南](human/services/media-pipeline-guide.md)
- [Memos 服务接入（SSO / 存储 / 通知 / AI）](human/services/memos.md)
- [Ignis 服务接入（Web Obsidian / vault / SSO）](human/services/ignis.md)
- [Frigate NVR 使用手册（乐橙摄像头）](human/services/frigate-nvr.md)
- [飞牛 fnOS NFS 媒体库接入](human/services/fnos-nfs-media.md)
- [RSS 链路](human/services/rss-chain.md)
- [SublinkPro 订阅管理](human/services/sublinkpro.md)
- [MoviePilot 插件配置](human/services/moviepilot-plugin-config.md)
- [协作内容链](human/services/collab-content-chain.md)

### 调研记录

- [调研索引](human/research/README.md)

### 学习笔记（项目相关）

- [学习索引](human/learning/README.md)

### 迁移与对齐（进行中）

- [2026-08-15 上游对齐审计（分批 backport）](human/migrations/upstream-alignment-audit-2026-08-15.md)
- [2026-08-20 macmini darwin 闭包导入加速](human/migrations/macmini-darwin-import.md)

## 历史归档（docs/archive/）

过时/已完成的历史记录，见 [`archive/README.md`](archive/README.md)。历史救援过程统一
放在归档区，不能直接当作当前操作步骤执行。
