# macmini 接管 Jellyfin：jellyfin-apple 公共模块迁移方案

> 状态：方案（待审阅）
> 日期：2026-08-20
> 决策人：zhyi
> 迁移目标：把 Jellyfin 从 rock5c（RK3588 rkmpp 硬解）迁到 macmini
> （Apple Silicon VideoToolbox 硬解），减轻 rock5c 负载。消费端一并改指向。

## 一、决策记录（用户已确认）

1. **Jellyfin 迁到 macmini**：直接切换（mac 接管，rock5c 停止 jellyfin）。
2. **HandBrake 不迁**：nixpkgs `handbrake` 在 darwin 上 `broken = stdenv.hostPlatform.isDarwin`
   （[PR #297984](https://github.com/NixOS/nixpkgs/pull/297984)），nix 无法在 mac 提供；
   保留 rock5c 的 handbrake-rockchip（RK3588 硬解）。**手刹不迁、不动。**
3. **MoviePilot 不迁**：nixpkgs 无 `aarch64-darwin` 的 moviepilot 包（`hasAttr=false`），
   且是 rock5c 上依赖 RK3588 生态的 podman 容器。保留 rock5c，通过 mac 的
   HTTP 私有入口跨机访问 Jellyfin。
4. **mac 入口形态**：mac 不装 nginx（`lantian.nginxVhosts` 映射到 NixOS 专属
   `services.nginx.virtualHosts`，nix-darwin 无此模块）。mac 上 Jellyfin 直接监听
   内网 TCP 端口，由 **opi5p / rock5c 上已有的 nginx** 回源指向 mac。零 TLS 重复、零证书管理。
5. **Jellyfin 数据**：迁移旧库（从 rock5c 拷贝配置/库 DB 到 mac）。

## 2. 现状拓扑（迁移前）

```
公网用户 --8443 DNAT-> opi5p:443
opi5p (jellyfin.zhyi.xin TLS) --http--> rock5c (jellyfin-backend.opi5p.zhyi.cc)
rock5c : jellyfin 本体(unix socket, RK3588 rkmpp) + MoviePilot(podman)
MoviePilot 容器 --add-host jellyfin-api.rock5c.zhyi.cc--> rock5c nginx --unix socket--> jellyfin
navdash : jellyfin 图标/媒体库 widget
```

- **Jellyfin 唯一服务端**：rock5c（RK3588S2，`jellyfin-rockchip.nix`，`lantian.jellyfinRockchip.soc = "rk3588"`）。
- **公网入口**：opi5p `edge-vhosts.nix` 的 `jellyfin.zhyi.xin`，proxy 到 rock5c。
- **MoviePilot**：rock5c podman，连 `jellyfin-api.rock5c.zhyi.cc`。
- **navdash**：jellyfin 图标/host/widget。
- **数据目录**：rock5c `/var/lib/jellyfin`（本机），媒体在 QNAP NFS `/mnt/storage`。
- **NFS 源**：QNAP `192.168.0.40:/nixos`（opus5/rock5c 用 Linux `/mnt/storage`，mac 用 `/Volumes/nixos`）。

## 3. 目标拓扑（迁移后）

```
公网用户 8443 DNAT --> opi5p:443
opi5p : jellyfin.vhyi.xin TLS --proxy--> macmini:8096 (mac 私有后端域名)
rock5c MoviePilot 容器 --add-host jellyfin-api.macmini.zhyi.cc--> rock5c nginx --> macmini:8096
macmini : jellyfin 本体 (launchd, VideoToolbox 硬解) 监听 8096
       数据: /Library/Application Support/Jellyfin
       媒体: /Volumes/nixos (QNAP NFS 同源)
navdash: jellyfin 图标/widget 改指 mac 入口
```

## 3. 可行性验证

- **Jellyfin darwin 包**：`pkgs.jellyfin` version 10.11.11，
  `meta.platforms` 含 `aarch64-darwin`，`meta.broken=false`，
  `dotnet-runtime.aspnetcore_9_0` 官方支持 darwin。✅
- **VideoToolbox 硬解**：jellyfin 官方明确 Apple Silicon 全硬解（H.264/HEVC/VP9 等），
  `jellyfin-ffmpeg`（基于 `ffmpeg_7-full`）darwin 自动启用 `--enable-videotoolbox`。✅
- **media 可达性**：macmini 已声明式挂载 QNAP NFS `/Volumes/nixos`（launchd+resvport），
  读媒体已验证。NFS 需 root 写（jellyfin launchd 以 root 运行可写）。✅
- **MoviePilot darwin** ✗ 不可用，保留 rock5c（见决策 3）。

## 4. 改动清单

### 新增公共模块
- **`nixos/optional-apps/jellyfin-apple.nix`**
  - `options.lantian.jellyfinApple.enable`
  - 仅 `config = lib.mkIf cfg.enable` 启用（公共模块规范）
  - 用 `launchd.daemons.jellyfin`（darwin 无 systemd）跑 `pkgs.jellyfin`
  - 环境变量开 VideoToolbox 硬解 + 禁止软件转码兜底
  - 数据目录 `/Library/Application Support/Jellyfin`（root 可写、持久）
  - 监听内网端口（mac 直监听，供 nginx 回源）

### macmini 主机接线
- `hosts/macmini/darwin-configuration.nix`：import + `lantian.jellyfinApple.enable = true`

### 消费端一起改
- **opi5p** `hosts/opi5p/edge-vhosts.nix`：`jellyfin.zhyi.xin` proxyPass 从
  rock5c 改指 macmini IP（192.168.0.54:8096 或私有后端域名）。
- **rock5c** `hosts/rock5c/media-edge.nix`：`jellyfin-api` vhost 回源改指 mac；
  `hosts/rock5c/configuration.nix`：MoviePilot `--add-host` 改 `jellyfin-api.macmini.zhyi.cc`
- **navdash** `nixos/optional-apps/navdash.nix`：jellyfin 图标/host 改指 mac 入口
- **数据迁移**：rock5c `/var/lib/jellyfin` 旧库拷到 mac，路径 `/mnt/storage` → `/Volumes/nixos`

### rock5c 停 jellyfin
- `hosts/rock5c/media-apps.nix`：移除 `jellyfin-rockchip` import、从 gatedServices 删 jellyfin
- `hosts/rock5c/configuration.nix`：删 `lantian.jellyfinRockchip.soc` 和相关 env
- **handbrake 不动**（决策 2）

## 5. 风险与回滚

- mac 上 jellyfin 首次全量拉 darwin 二进制慢（已知缓存缺口），分批部署可回滚。
- MoviePilot 连接若断，影响媒体自动化，先改 navdash/公网入口再停 rock5c。
- 所有主机级改动可 git revert 回滚；rock5c jellyfin 保留模块不删，仅改 enable。
