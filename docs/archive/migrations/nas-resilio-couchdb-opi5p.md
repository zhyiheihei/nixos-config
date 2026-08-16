# QNAP NAS 容器迁移到 OPI5P（resilio-sync，2026-08）

把 QNAP Container Station（`192.168.0.40`）上 Docker 运行的 resilio-sync 迁移到
opi5p 原生 Nix 服务，按"原生 Nix 包优先"约定不再依赖 QNAP Docker。

## 迁移范围

| 服务 | NAS 容器 | 数据量 | opi5p 落位 |
| --- | --- | --- | --- |
| resilio-sync | `lscr.io/linuxserver/resilio-sync`，`:8888` UI / `:55555` 同步 | 配置 2G + 数据 358G | nixpkgs `resilio-sync` 3.1.1.1075 + 自建 systemd 服务 |

couchdb-obsidian-livesync 曾计划一并迁移，因迁移操作事故数据丢失（见下文
"couchdb 事故记录"），用户决定放弃该服务。

不迁移（留在 NAS）：`proxmox-backup-server`、`qnap-k3s`、`mt-photos`。

## 包来源结论（2026-08-14 验证）

- `resilio-sync`：nixpkgs 有包（unfree，`allowUnfree` 已由 xddxdd nixpkgs-options
  模块默认开启），但全 GitHub/NUR 无 NixOS 模块，在 `nixos/optional-apps/` 自建。
- `couchdb`：nixpkgs 有包（`couchdb3`）和 `services.couchdb` 模块，已弃用。

## 迁移后拓扑（resilio）

- opi5p 原生 systemd `resilio.service`（unit 名匹配现有日志过滤规则）
- 身份/配置：`/var/lib/resilio-sync`（本地持久化；备份排除 `*.db` 规则已存在；
  用户固定 uid/gid 1002，便于部署前 chown）
- 同步数据：`/mnt/storage/resilio/data`（NFS），bind 到 `/sync`；
  `downloads` bind 到 `/downloads`（数据库内路径硬编码 `/sync/...`，bind 保持零改动）
- webui 监听沿用迁移配置 `0.0.0.0:8888`（LAN 内访问）

## 数据迁移步骤（已完成）

1. 停容器：`docker stop couchdb-obsidian-livesync resilio-sync`（restart 策略已改 `no`）
2. 数据移动：单挂载点 docker 容器内 `mv`（`/share/CACHEDEV1_DATA:/vol`，
   `mv /vol/Container/resilio /vol/nixos/resilio`）——同卷原子 rename
   （注：双挂载点时 busybox mv 会误判跨设备走 copy+delete，勿再用）
3. 属主：在 NAS 本地用 docker 容器 `chown -R 1002:1002`（不要在 opi5p 上经 NFS
   做大规模 chown——元数据风暴曾导致 opi5p 内核卡死，见事故记录）
4. opi5p：`/var/lib/resilio-sync` 就位（config 目录从 NFS 拷入，`sync.conf`
   的 `storage_path` 改为 `/var/lib/resilio-sync`）

## 服务部署（已完成）

- opi5p `colmena apply`：resilio.service 运行中，监听 `:8888`（WebUI）与
  `:55555`（同步，双栈）；`/sync`、`/downloads` bind 到 NFS
- rock5c `colmena apply`：couchdb.zhyi.xin vhost 移除（DNS 记录已从配置删除，
  尚未跑 `dnscontrol push` 生效）

## 外部直连：UPnP 自动端口映射（已完成）

router 本就运行 miniupnpd（`optional-apps/miniupnpd.nix`），resilio 通过
NAT-PMP 自动申请 `WAN:55555 → opi5p:55555`，无需手动 DNAT。修复过程中发现
并解决两个问题：

1. 仓库模块里 xddxdd 时代的 `ExecStartPre=iptables_init.sh` 覆盖在纯 nftables
   路由器上无法工作（且会让任何重启失败）——已删除；
2. nixpkgs miniupnpd 模块的 nftables 后端调用 `nft`，但 NixOS systemd 服务
   PATH 不含 `/run/current-system/sw/bin`，导致所有映射添加失败
   （"Failed to add NAT-PMP ..."，Syncthing 22000 同样中招）——已加
   `systemd.services.miniupnpd.path = [ pkgs.nftables ]`。

验证：nftables `prerouting_miniupnpd` 链出现 `ppp0 tcp/udp dport 55555 →
192.168.0.62:55555` 自动规则；从公网 VPS（greencloud）`nc -zv 115.215.8.194
55555` 成功。注：LAN 内访问 WAN IP 的 hairpin 会被 lantian 防火墙的 catch-all
规则接管（LAN 客户端应直接用 LAN IP）。

## 验证

- resilio：webui `http://192.168.0.62:8888`（沿用迁移账号）、
  `systemctl status resilio` active、同步文件夹正常索引
- 外部直连：`nc -zv <WAN-IP> 55555` 成功（见上）

## 回滚

- QNAP resilio 容器保持停止、未删除；数据已移至
  `/share/CACHEDEV1_DATA/nixos/resilio`（= opi5p `/mnt/storage/resilio`）
- 回滚：停止 opi5p 服务 → 将目录 mv 回 `/share/Container/resilio` → 启动 QNAP 容器
- 注意：容器 `restart` 策略已改为 `no`，NAS 重启不会自动拉起旧容器

## couchdb 事故记录（2026-08-14）

迁移执行中，couchdb 数据（2.8G，Obsidian Livesync 数据库）因操作序列失误丢失：
容器内双挂载点 `mv` 实际执行了 copy+delete（busybox 跨挂载点误判），随后清理
"部分拷贝"时把已移入 NFS share 的完整数据一并删除；QNAP 回收站/快照均无可用副本，
ext4 文件系统级恢复未尝试（用户放弃）。教训：容器内跨 bind mount 的文件操作必须
单挂载点执行；清理目标路径前先确认其内容来源。

couchdb 相关代码已全部移除（模块、opi5p 配置、rock5c vhost、DNS 记录、端口常量）；
`nixos-secrets/common/couchdb.yaml` 与 flake.lock 的 secrets 钉住保留（无副作用）。
QNAP 上 `couchdb-obsidian-livesync` 容器保留停止状态，`restart` 策略已改为 `no`。

## 待办

- Obsidian Livesync 如后续重建，需要新的数据库/凭据（可复用
  `nixos/optional-apps/` 中删除前的模块设计，git 历史可找回）
- resilio 稳定 1-3 天后，用户决定是否清理 NAS 侧任何残留
