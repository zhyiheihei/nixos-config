# 文档索引

配置的最终来源始终是 `hosts/`、`nixos/`、`helpers/`、`dns/` 与 `Makefile`。
本文档只记录当前操作约束、架构解释和经验证的迁移记录；历史救援过程统一放在
[`old/`](./old/README.md)，不能直接当作当前操作步骤执行。

## 日常操作

- [构建与部署当前主机](./deployment.md)
- [新主机接入规范](./new-host-standard.md)
- [适配自己的 NixOS 设备](./adapt-own-device.md)
- [Gcore 免费套餐 DNSControl 发布规范](./gcore-dnscontrol-free-plan.md)

## 基础设施

- [网络参照](./network-reference.md)
- [域名与服务编排](./domain-service-layout.md)
- [家庭局域网 IP 规划](./home-lan-ip-plan.md)
- [LTNET 家庭中继与缓存链路](./network/ltnet-home-relay.md)
- [DN42 接入准备](./network/dn42-bootstrap.md)
- [OpenWrt 两级路由网段互访配置](./opentwrt-two-router-interlan.md)
- [自建 Attic + S3 构建缓存](./attic-s3-cache.md)
- [自有 Attic 优先与完整闭包缓存](./attic-owned-cache-priority.md)
- [Attic 手动补推缓存流程](./attic-full-store-push.md)
- [Attic 旧客户端缓存排障](./attic-stale-client-cache-troubleshooting.md)

## 主机与服务

- [当前 hosts 概览](./hosts-overview.md)
- [ml-2700u 安装与桌面操作](./ml-2700u/README.md)
- [Homepage 链接与监测检查](./homepage-link-audit.md)

## 迁移与验收记录

- [ml-home-vm 与 pve-5700u 复刻验收](./vm-replication-chain.md)
- [1Panel 服务迁移到 ml-home-vm](./onepanel-to-ml-home-vm-migration.md)
- [ml-home-vm VirtioFS 与 PVE 迁移手册](./ml-home-vm-virtiofs-pve-migration.md)

## 历史归档

历史安装日志、临时 Docker 构建方案和已经完成的救援记录见
[`docs/old/`](./old/README.md)。
