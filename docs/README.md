# 文档索引

配置的最终来源始终是 `hosts/`、`nixos/`、`helpers/`、`dns/` 与 `Makefile`。
本文档只记录当前操作约束、架构解释和经验证的迁移记录；历史救援过程统一放在
[`old/`](./old/README.md)，不能直接当作当前操作步骤执行。

## 入门与主机接入

- [适配自己的 NixOS 设备](./getting-started/adapt-own-device.md)
- [新主机接入规范](./getting-started/new-host-standard.md)
- [客户端设备入网指南](./getting-started/client-device-onboarding.md)

## 构建与运维

- [构建与部署当前主机](./operations/deployment.md)
- [NixOS 完整重装指南](./operations/nixos-reinstallation-guide.md)
- [ml-builder 验收与排障](./operations/test-ml-builder.md)

## 硬件适配

- [ARM 开发板 NixOS 适配手册](./hardware/arm-board-bring-up.md)
- [HINLINK H28K（RK3528）NixOS 路由器适配](./hardware/hinlink-h28k.md)
- [NanoPi R5C NixOS 镜像适配与安装](./hardware/nanopi-r5c.md)
- [NanoPi R5C 内核与系统闭包裁剪审计](./hardware/nanopi-r5c-size-audit.md)
- [NanoPi R5C：从 macOS 写入 SD 卡到读取串口日志](./hardware/nanopi-r5c-flash-and-serial.md)
- [Orange Pi Zero 3 NixOS 启动适配](./hardware/orangepi-zero3.md)
- [Orange Pi Zero 3：H618 reDroid 12、Mali GPU 与 Cedar 硬解](./hardware/orangepi-zero3-redroid.md)

## 网络

- [网络参照](./network/reference.md)
- [家庭局域网 IP 规划](./network/home-lan-ip-plan.md)
- [LTNET 家庭中继与缓存链路](./network/ltnet-home-relay.md)
- [DN42 当前拓扑](./network/dn42.md)

## 基础设施

- [域名与服务编排](./infrastructure/domain-service-layout.md)
- [Gcore 免费套餐 DNSControl 发布规范](./infrastructure/gcore-dnscontrol-free-plan.md)
- [自建 Attic + S3 构建缓存](./infrastructure/attic-s3-cache.md)
- [自有 Attic 优先与完整闭包缓存](./infrastructure/attic-owned-cache-priority.md)
- [Attic 手动补推缓存流程](./infrastructure/attic-full-store-push.md)
- [Hydra 构建链路与并发约束](./infrastructure/hydra-build-chain.md)
- [AI API 网关链路与初始化规范](./infrastructure/ai-api-gateway-chain.md)
- [Prometheus / Grafana 监控链路](./infrastructure/monitoring.md)

## 服务指南

- [Homepage 卡片与健康检查](./services/homepage-link-audit.md)
- [下载与媒体链路使用指南](./services/media-pipeline-guide.md)

## 状态参考

- [当前 hosts 概览](./reference/hosts-overview.md)

## 迁移与验收记录

- [2026-08-03 作者配置复刻偏移审计](./migrations/upstream-replica-audit-2026-08-03.md)
- [2026-07-28 上游对齐偏差审计](./migrations/upstream-alignment-audit-2026-07-28.md)
- [下载与媒体链路迁移到 OPI5P](./migrations/opi5p-media-pipeline.md)
- [colocrossing 迁移到新加坡节点](./migrations/colocrossing-sg-migration.md)
- [ml-home-vm 与 pve-5700u 复刻验收](./migrations/vm-replication-chain.md)
- [ml-home-vm VirtioFS 与 PVE 迁移手册](./migrations/ml-home-vm-virtiofs-pve-migration.md)

## 历史归档

历史安装日志、临时 Docker 构建方案和已经完成的救援记录见
[`docs/old/`](./old/README.md)。
