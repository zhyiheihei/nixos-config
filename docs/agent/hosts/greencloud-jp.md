# greencloud-jp（APAC 存储 VPS，40G 系统盘 + 1T 数据盘）

机群的异地存储与备份端。`hosts/greencloud-jp/*.nix` 不写注释，理由记录在本文件。

## 存储

- **VaultS3 的 S3 网关**（`s3.zhyi.xin`）：数据放 1T 数据盘，只监听 loopback，由
  nginx 用泛域名证书反代。与 router 上的实例共用机群统一凭据约定；router 上的旧
  实例已停摆。Attic 等缓存后端用它作 S3 存储。
- **SFTP 备份端点**（internal-sftp chroot）：`ChrootDirectory` 要求整条路径 root 属主，
  所以 home 本身 root 属主，数据写进内部 sftp 可写的 `backups/restic` 子目录；
  chroot 目录也在 1T 数据盘上。它是 storagebox 双备份仓库根之一（见
  `minimal-components/backup/common.nix`）。
- 本机是机群的异地备份目标，**不再向外推送自身备份**。
- **Syncthing**：机群常在线的异地端（自 greencloud 移交），存储放 1T 数据盘（默认值
  在 40G 系统盘上放不下）；Obsidian vault 固定目录与 opi5p 的 Ignis vault 同名，便于
  Syncthing 对接。

## Git / Gitea

- Gitea 自 greencloud 迁入（2026-08-29，模块自带 mysql 依赖）；LFS/附件存储指向本机
  VaultS3。
- **裸仓迁 1T 数据盘**（2026-09-17 故障复盘）：dooya SDK 裸仓 33G 把 39G 系统盘塞爆 →
  postgres 写失败 `start-limit-hit` 不重启 → attic 数据库连接 500 → 全舰队部署拉包
  失败。LFS/附件已在 VaultS3，裸仓同步迁出；`stateDir`（配置/密钥/索引）仍留
  `/nix/persistent`。

## 停用项

- **Nextcloud**：按上游停用（`oracle-vm-arm1` 注释该模块），用户 2026-10-22 要求跟随；
  主机级配置保留在 `./nextcloud.nix` 便于随时恢复。该文件里：上游
  `dbtype = "oci"` 连的是作者自己的 Oracle ADB 实例，本机没有 Oracle，改用宿主已有
  MariaDB（与 Gitea 同库），socket 免密认证；`RestartSec` 按上游 b1383d16 断言补齐；
  Nextcloud 自己发 `X-Robots-Tag: none`，不需要 `noIndex`。
- **atticd**：按上游停用（服务下线，域名留给占位说明页）。

## 网络

- 该机房 DHCPv4 拿不到租约，v4/v6 都是静态（网关为救援环境实测值）；双栈全静态时
  显式关 RA，防止机房意外下发第二条默认路由（同 tencent 写法）。
- 作为 cn-accel 出口节点，默认 vhost 的 `/ray` 走真证书（同 tencent；xray 服务由
  `cn-accel` 标签经 `server-apps/v2ray.nix` 启用）。

## 硬件/主机元数据

GreenCloud APAC 存储 VPS：`vda` 40G 系统盘（BIOS 三分区），`vdb` 1T 数据盘；UUID
现场采集于 2026-08-29 的 Alpine RAM 安装环境。1T 盘承载 SFTP chroot 与 S3 网关数据。
主机密钥 2026-08-29 安装时生成在 `/nix/persistent/etc/ssh`
（指纹 `SHA256:GJ8IBWu9Q3aPIOaYm8uc62XlJQaPagPjQ+4dyxaZGgk`）；ZeroTier node ID
采集于 2026-08-29 首启（`zerotier-cli info`）。
