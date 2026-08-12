# Router qBittorrent 三实例迁移方案

状态：已完成（2026-08-06）  
日期：2026-08-06  
目标：把 opi5p 上的 `qbittorrent`、`qbittorrent-pt`、`qbittorrent-seedbox` 三个下载器迁移到 `router`，下载路径继续使用 QNAP NFS `/mnt/storage`。

> 2026-08-12 规范化：公共模块保持不动，router 的
> `hosts/router/qbittorrent.nix` 只导入现有 `qbittorrent.nix`，并写主机级扩展键
> （官方客户端、固定端口、单接口绑定、统一保存路径、WebUI 白名单）与目录映射；
> 单实例即当前唯一 qBittorrent，不再聚合弃用实例。

## 1. 现状与前提

- router 已部署 NFS 客户端并实测挂载成功：`192.168.0.40:/nixos` 挂到 `/mnt/storage`，NFSv4.1，`nofail`，不影响网关启动。
- router `/var/lib` 是 `/nix/persistent/var/lib` 的 btrfs 子卷绑定挂载，三个 qBittorrent 的 `StateDirectory` 会持久化，重启不丢状态。
- router 当前资源：4 核、3.1 GiB 可用内存、`/nix` 约 27 GiB 可用。
- opi5p 当前状态目录约 `21M / 37M / 31M`，下载任务和 torrent 数据都在 NAS，不需要复制媒体文件。
- 现有公开 WebUI 由 router 自身 nginx 服务 `bt.router.zhyi.cc`、`pt.router.zhyi.cc`、`seedbox.router.zhyi.cc`；rock5c 边缘 localhost 入口直连 router WebUI 端口。
- 消费方包括：opi5p FlexGet/PeerBanHelper/IYUU/JProxy/BitMagnet、router
  `qbittorrent-pt-cleanup`、rock5c Sonarr/Radarr 与 localhost 边缘入口。

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

实际采用 router 自身 nginx + 证书：

- router 服务 `bt.router.zhyi.cc`、`pt.router.zhyi.cc`、`seedbox.router.zhyi.cc`。
- 防火墙在 WAN 侧拒绝直连 WebUI 端口 `13808 / 13809 / 13830`。
- rock5c 边缘 `bt/pt/seedbox.localhost` 直连 router WebUI 端口，供 homepage 组件使用。

### 3.3 消费方范围

- rock5c `media-edge.nix`：`bt / pt / seedbox` 的 localhost `proxyPass` 改为 router LAN 端口。
- opi5p FlexGet：`qbittorrent.host` 改为 `192.168.0.1`，PT cleanup 已随下载器迁到 router。
- PeerBanHelper：`config.yml` 三个 endpoint 改为 router，回调 prefix 改为 `192.168.0.62:9898`。
- IYUU：通过官方管理端 API 初始化三个下载器，PT 为默认。
- Sonarr/Radarr：下载客户端 host 改为 `pt.router.zhyi.cc:443`。

## 4. 实施步骤

### 4.1 准备 router 配置

新建 `hosts/router/qbittorrent.nix`，导入三个公共 qBittorrent 模块和 `nixos/common-apps/nginx/vhost-options/default.nix`，然后主机级覆盖：

- 三个服务的 `ExecStart` 使用显式入站端口 `31220 / 31221 / 31222`。
- 三个服务 `after = [ "mnt-storage.mount" ]`、`requires = [ "mnt-storage.mount" ]`。
- 保持 `StateDirectory` 与下载目录 BindPaths 和 opi5p 一致。
- 用激活 marker `/nix/persistent/var/lib/qbittorrent-router/ready` 防止部署后在状态复制前启动空实例。
- 防火墙 `publicFirewalledPorts` 增加三个 WebUI 端口。
- `qbittorrent-pt-cleanup` 一并迁到 router。

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
  install -Dm600 /dev/null /nix/persistent/var/lib/qbittorrent-router/ready
'
```

### 4.4 启动并验收 router

```bash
ssh -p 2222 root@192.168.0.1 '
  systemctl start qbittorrent-router.target
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
- 修改 opi5p FlexGet 指向并部署，禁用本机 qBittorrent 与 PT cleanup。
- PeerBanHelper 配置文件改为 router 地址并重启。
- IYUU 通过官方 API 初始化三个下载器。
- Sonarr/Radarr 通过官方 API 改为 `pt.router.zhyi.cc` 并测试连通。

## 6. 执行结果

- router：三个 qBittorrent 与 PT cleanup 均 active，任务数 `0 / 60 / 24`。
- router：`bt/pt/seedbox.router.zhyi.cc` 已由 router nginx 服务。
- opi5p：本机 qBittorrent 已停用，FlexGet/PeerBanHelper/IYUU 已改连 router。
- rock5c：Sonarr/Radarr 下载客户端测试通过，localhost 边缘入口全部 200。
- homepage：链接已更新为 `*.router.zhyi.cc`。
- 唯一保留空转的是 FlexGet 的 RSS 订阅，等待后续配置 RSS 源。

## 5. 回滚

```bash
ssh -p 2222 root@192.168.0.1 '
  systemctl stop qbittorrent-router.target
  rm -f /nix/persistent/var/lib/qbittorrent-router/ready
'

ssh -p 2222 root@192.168.0.62 '
  systemctl start qbittorrent.service qbittorrent-pt.service qbittorrent-seedbox.service
  systemctl start flexget-runner.timer qbittorrent-pt-cleanup.timer
'
```

回滚后不要把 router 运行期间产生的新状态反向覆盖 opi5p；需要保留的新任务应单独导出。
