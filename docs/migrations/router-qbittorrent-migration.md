# Router qBittorrent 三实例迁移方案

状态：执行中（下载器已迁到 router，IYUU 待 WebUI 更新）  
日期：2026-08-06  
目标：把 opi5p 上的 `qbittorrent`、`qbittorrent-pt`、`qbittorrent-seedbox` 三个下载器迁移到 `router`，下载路径继续使用 QNAP NFS `/mnt/storage`。

## 1. 现状与前提

- router 已部署 NFS 客户端并实测挂载成功：`192.168.0.40:/nixos` 挂到 `/mnt/storage`，NFSv4.1，`nofail`，不影响网关启动。
- router `/var/lib` 是 `/nix/persistent/var/lib` 的 btrfs 子卷绑定挂载，三个 qBittorrent 的 `StateDirectory` 会持久化，重启不丢状态。
- router 当前资源：4 核、3.1 GiB 可用内存、`/nix` 约 27 GiB 可用。
- opi5p 当前状态目录约 `21M / 37M / 31M`，下载任务和 torrent 数据都在 NAS，不需要复制媒体文件。
- 现有公开 WebUI 由 router 自身 nginx 服务 `bt.router.zhyi.cc`、`pt.router.zhyi.cc`、`seedbox.router.zhyi.cc`；rock5c 边缘 localhost 入口直连 router WebUI 端口。
- 消费方包括：rock5c 边缘代理、opi5p FlexGet（localhost:13809）、`qbittorrent-pt-cleanup`、PeerBanHelper、IYUU、Sonarr/Radarr/Prowlarr/JProxy。

## 2. 不变量

- 同一时间只有一台机器运行写服务，qBittorrent 和自动化消费方不能同时写同一批 NFS 路径。
- 下载保存路径不变：`/mnt/storage/downloads`、`.downloads-qb`、`.downloads-qb-pt`、`.downloads-qb-seedbox`、`.downloads-auto`。
- 不修改公共模块：所有差异通过 `hosts/router/`、`hosts/opi5p/`、`hosts/rock5c/` 主机级配置实现。
- 构建只发生在 ml-builder；部署使用显式 `colmena apply --on <host>`。

## 3. 待确认决策

### 3.1 入站端口

opi5p 当前入站端口为 `31220 / 31221 / 31222`。router 按 `wg-zhyi.forwardStart` 推导会得到 `31120 / 31121 / 31122`。

推荐保持 `31220 / 31221 / 31222` 不变，避免私站端口检查、防火墙规则和客户端配置一起变更。router 主机级配置显式覆盖三个服务的 `torrenting-port`。

### 3.2 WebUI 入口

router 是 minimal 角色，没有完整 nginx 反代链。推荐：

- qBittorrent WebUI 只监听 LAN，防火墙在 WAN 侧拒绝 `13808 / 13809 / 13830`。
- 公开入口继续走 rock5c 边缘，把 `bt`、`pt`、`seedbox` 后端从 opi5p 切到 `192.168.0.1` 对应端口，域名可暂时保留，避免 DNS 和证书迁移。

备选方案是在 router 上启用 nginx 与证书，工作量和暴露面更大，默认不选。

### 3.3 消费方范围

- rock5c `media-edge.nix`：`bt / pt / seedbox` 的 `proxyPass` 改为 router LAN 地址。
- opi5p FlexGet：`qbittorrent.host` 从 `localhost` 改为 `192.168.0.1`。
- opi5p `qbittorrent-pt-cleanup`：`QBITTORRENT_URL` 改为 `http://192.168.0.1:13809`。
- PeerBanHelper：当前在 opi5p 上 `after/requires qbittorrent.service`，qBittorrent 移除后必须同步改主机级配置（改连 router）或随下载器一起迁移，否则 unit 会因依赖缺失失败。
- IYUU、JProxy、Sonarr/Radarr/Prowlarr：如果公开域名入口不变，主要是下载客户端地址或反向代理后端更新。

## 4. 实施步骤

### 4.1 准备 router 配置

新建 `hosts/router/qbittorrent.nix`，导入三个公共 qBittorrent 模块和 `nixos/common-apps/nginx/vhost-options/default.nix`，然后主机级覆盖：

- 三个服务的 `ExecStart` 使用显式入站端口 `31220 / 31221 / 31222`。
- 三个服务 `after = [ "mnt-storage.mount" ]`、`requires = [ "mnt-storage.mount" ]`。
- 保持 `StateDirectory` 与下载目录 BindPaths 和 opi5p 一致。
- 用激活 marker（例如 `/nix/persistent/var/lib/qbittorrent-migrated`）防止部署后在状态复制前启动空实例。
- 防火墙 `publicFirewalledPorts` 增加三个 WebUI 端口。

先部署 router 配置，不创建 marker，因此服务不会启动。

### 4.2 冻结 opi5p

```bash
ssh -p 2222 root@192.168.0.62 '
  systemctl stop flexget-runner.timer qbittorrent-pt-cleanup.timer
  systemctl stop qbittorrent.service qbittorrent-pt.service qbittorrent-seedbox.service
  systemctl is-active qbittorrent qbittorrent-pt qbittorrent-seedbox
'
```

确认三个实例都是 `inactive`，再记录任务数：

```bash
ssh -p 2222 root@192.168.0.62 '
  for port in 13808 13809 13830; do
    curl -fsS -u "$QB_USER:$QB_PASS" \
      "http://127.0.0.1:$port/api/v2/torrents/info" | jq length
  done
'
```

`QB_USER` / `QB_PASS` 按三个实例现有的 WebUI 凭据填写；任务数先落盘保存，作为切换后对账基准。

### 4.3 迁移状态

```bash
ssh -p 2222 root@192.168.0.62 '
  tar --acls --xattrs --numeric-owner -C /var/lib -cpf - \
    qbittorrent qbittorrent-pt qbittorrent-seedbox
' |
ssh -p 2222 root@192.168.0.1 '
  tar --acls --xattrs --numeric-owner -C /nix/persistent/var/lib -xpf -
  chown -R zhyi:users /nix/persistent/var/lib/qbittorrent \
    /nix/persistent/var/lib/qbittorrent-pt \
    /nix/persistent/var/lib/qbittorrent-seedbox
  install -Dm600 /dev/null /nix/persistent/var/lib/qbittorrent-migrated
'
```

### 4.4 启动并验收 router

```bash
ssh -p 2222 root@192.168.0.1 '
  systemctl start qbittorrent.target
  systemctl is-active qbittorrent qbittorrent-pt qbittorrent-seedbox
  for port in 13808 13809 13830; do
    curl -fsS -u "$QB_USER:$QB_PASS" \
      "http://127.0.0.1:$port/api/v2/torrents/info" | jq length
  done
'
```

验收项：

1. 三个实例任务数与冻结前一致，保存路径和完成进度一致。
2. `findmnt /mnt/storage` 仍正常，`journalctl -u mnt-storage.mount` 无报错。
3. WebUI 可从 LAN 或 rock5c 边缘访问。
4. Sonarr/Radarr 下载客户端测试通过，FlexGet 和 PT cleanup 能连上新地址。
5. PeerBanHelper / IYUU 与三个下载器连通，Prometheus 无对应失败指标。
6. router 内存和负载在可接受范围。

### 4.5 切换消费方

- 修改 rock5c `media-edge.nix` 后端地址并部署。
- 修改 opi5p FlexGet 与 cleanup 的指向并部署。
- PeerBanHelper 按确认方案处理。
- 确认消费方全部连通后，再移除 opi5p 上的 qBittorrent 模块，防止双写。

## 5. 回滚

```bash
ssh -p 2222 root@192.168.0.1 '
  systemctl stop qbittorrent.target
  rm -f /nix/persistent/var/lib/qbittorrent-migrated
'

ssh -p 2222 root@192.168.0.62 '
  systemctl start qbittorrent.service qbittorrent-pt.service qbittorrent-seedbox.service
  systemctl start flexget-runner.timer qbittorrent-pt-cleanup.timer
'
```

回滚后不要把 router 运行期间产生的新状态反向覆盖 opi5p；需要保留的新任务应单独导出。
