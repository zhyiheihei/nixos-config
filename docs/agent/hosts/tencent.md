# tencent（Tencent Cloud CVM，首尔）

监控与个人门户所在的公网主机。`hosts/tencent/*.nix` 不写注释，理由记录在本文件。

## 服务

- **Prometheus / Grafana / Alertmanager**：监控栈 2026-08-14 自 greencloud 迁入。
  `prometheus.tencent.zhyi.xin` 是给 Homepage 资源卡片用的只读 API，`accessibleBy =
  private`：Homepage 通过 DNS 把该域名解析到 tencent 的 LTNET 地址
  （`198.18.0.128`），公网不可达。
- **Lsky Pro 图床**（`pic.zhyi.xin`）：2026-09-11 新增，用官方 Docker 镜像。
- **hubproxy**：容器镜像加速入口（docker/gcr/quay/k8s.io 前缀路由）。
- **navdash**（个人服务门户 `nav.zhyi.xin`）：原生 OIDC 登录，卡片在求值期生成。
- **archiveteam**：ArchiveTeam warrior，2026-09-02 自 rock5c 迁入——warrior 镜像只有
  amd64 变体，aarch64 主机跑不了（与 clawemail 同一决策，见 `690b0d26`）。
  `clawemail` 本体目前停用。
- **radicale-calendar-sync**：2026-08-31 自 greencloud 迁入，每小时同步。脚本按主机名
  取 `secrets/per-host/radicale-calendar-sync/tencent.yaml`；Radicale 服务端仍在
  greencloud，脚本内目标地址指向其公网入口。
- **cn-accel 出口**：默认 vhost 的 `/ray`（v2ray xhttp）挂真证书，让 cn-accel 客户端
  能校验 TLS（mesh 默认 vhost 只有 snakeoil 证书）。

## 停用项

- **searxng**：上游已停用（`pve-epyc` 注释该模块：missing regenerated secret），按用户
  2026-10-22 要求跟随停用。uwsgi 的 confinement 依赖（`/run/searx`、vassal 降权）也
  一并移除。若要重启：重新导入 `searxng.nix` 后，uwsgi 必须给 chroot 补
  `/etc/passwd`、`/etc/group`、`/etc/nsswitch.conf`（vassal 用 immediate-uid/gid 符号名
  降权）与 `/run/searx`（`searx-init` 的 RuntimeDirectory，socket 与 `settings.yml`
  都在里面）。

## 网络

- Tencent 给的公网 IPv6 是静态 /128；网关是子网路由器的 link-local（由 MAC
  `fe:ee:6c:22:4a:de` 派生），机房不下发 RA 默认路由（`accept_ra` 保持关闭）。

## 硬件/主机元数据

- Tencent Cloud CVM（首尔）存储布局按项目统一服务器架构：tmpfs `/`
  （impermanence）、独立 `/boot`、持久 btrfs `/nix`（`neededForBoot = true`）。
- BIOS 布局（安装环境确认过 `test -d /sys/firmware/efi` 为假）：2 MiB bios_grub
  （不挂载）+ 1 GiB ext4 `/boot` + btrfs `/nix`；`boot.loader.grub.device =
  "/dev/vda"`。设备路径在 live 环境确认过，UUID 可按
  [nixos-reinstallation-guide](../nixos-reinstallation-guide.md) §3.3 替换。
- 主机密钥 2026-08-13 重装时生成在 `/nix/persistent/etc/ssh`
  （指纹 `SHA256:mQsADD14m6vckwHEmIan3gOcixlPtRos7eaNQQNiCEo`）；ZeroTier node ID
  于 2026-08-13 首启采集。
