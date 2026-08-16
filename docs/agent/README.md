# agent 规范索引（给 agent 看的）

> 本目录是「给 agent 看的」执行规范与参照：本仓库 agent 干活前必读，改动时必须遵守。
> 目录划分规则见 [`../README.md`](../README.md)。给人看的指南与记录在 `../human`，
> 过时归档在 `../archive`。

## 必读（每次任务开始前）

1. [`work-norms.md`](work-norms.md) —— 工作规范十条（提交+对齐、对照上游、不动公共模块、查证不猜、巡检看指标、聚焦任务、构建只用 ml-builder、大任务先出方案）
2. [`skills-recommendation.md`](skills-recommendation.md) —— 任务分级（S/M/L/Debug）与 skill 使用；冲突时以工作规范为准
3. [`ai-api-gateway-chain.md`](ai-api-gateway-chain.md) —— AI 网关链路硬约束（UniAPI 唯一汇聚点）
4. [`module-placement-norms.md`](module-placement-norms.md) —— 模块分层与参数归属
5. [`hosts-overview.md`](hosts-overview.md) —— 当前主机清单与拓扑
6. [`new-host-standard.md`](new-host-standard.md) —— 新主机接入流程

## 操作手册

- [`development-handbook.md`](development-handbook.md) —— 快速放置决策、新增 flake 输入、添加模块/overlay、分配端口
- [`deployment.md`](deployment.md) —— 构建与 Colmena 部署
- [`test-ml-builder.md`](test-ml-builder.md) —— ml-builder 验收与排障
- [`nixos-reinstallation-guide.md`](nixos-reinstallation-guide.md) —— NixOS 完整重装
- [`inspection-playbook.md`](inspection-playbook.md) —— 巡检手册（看报错/指标）

## 主题规范与参照

| 主题 | 文档 |
| --- | --- |
| 域名与服务编排 | [`domain-service-layout.md`](domain-service-layout.md)、[`service-domain-norms.md`](service-domain-norms.md) |
| 网络参照 | [`reference.md`](reference.md)、[`home-lan-ip-plan.md`](home-lan-ip-plan.md) |
| 构建缓存 | [`attic-s3-cache.md`](attic-s3-cache.md)、[`attic-owned-cache-priority.md`](attic-owned-cache-priority.md)、[`attic-full-store-push.md`](attic-full-store-push.md)、[`hydra-build-chain.md`](hydra-build-chain.md) |
| 身份与认证 | [`identity-auth-architecture.md`](identity-auth-architecture.md)、[`oidc-app-integration.md`](oidc-app-integration.md) |
| DNS 发布 | [`gcore-dnscontrol-free-plan.md`](gcore-dnscontrol-free-plan.md) |
| 监控 | [`monitoring.md`](monitoring.md) |
| 服务位置 | [`fleet-service-chain.md`](fleet-service-chain.md) |

> 仓库结构详解（目录树、模块分层表、标签、架构图）见 [`../human/reference/repository-structure.md`](../human/reference/repository-structure.md)。
