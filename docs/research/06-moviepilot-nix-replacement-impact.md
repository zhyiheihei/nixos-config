# 调研文档 06：MoviePilot 从 podman 切到 Nix 包的影响评估

> 日期：2026-08-12。范围：`hosts/rock5c` 上正在运行的
> `podman-moviepilot.service`。上游 `nixos-config-exam` 没有 MoviePilot
> 模块，因此不受“上游 podman 则不切换”约束，但生产切换仍需逐项验证。

## 当前 podman 形态

- 镜像：`docker.io/jxxghp/moviepilot-v2:latest`。
- 数据目录：`/nix/persistent/var/lib/moviepilot`，容器内为 `/config`。
- 端口：宿主只暴露前端 `LT.portStr.MoviePilot.Frontend` -> 容器 `3000`；
  后端在容器内 `3001`。
- 环境：`TZ`、`PORT=3001`、`NGINX_PORT=3000`、
  `MOVIEPILOT_AUTO_UPDATE=false`、`DB_TYPE=sqlite`、
  `CACHE_BACKEND_TYPE=cachetools`。
- 卷：数据目录、`.cloakbrowser`、整个 `/mnt/storage`（避免 NFS 子目录
  破坏 hardlink 导入）。
- `rock5c` 额外：通过 SOCKS5 代理环境变量走家庭路由器出口；
  `--add-host=jellyfin-api.rock5c.zhyi.cc:LAN-IP`；
  `moviepilot-plugin-health` 定时服务恢复 BrushFlow/SubtitleAssistant 路由。

## Nix 包形态

- 包：`zhyi-packages#moviepilot`（当前 v2.15.5）。
- wrapper：`moviepilot` 启动 `python -m app.cli`，`CONFIG_DIR` 默认
  `$XDG_CONFIG_HOME/moviepilot`，可显式设置。
- 包内已集成前端 dist、前端 runtime（`service.js` + node_modules）与
  `resources.v2`。

## 需要验证/有风险的差异

1. `CONFIG_DIR` 必须指向现有 `/nix/persistent/var/lib/moviepilot`，
   否则 SQLite 和配置是空库。
2. 前端 `NGINX_PORT=3000` / 后端 `PORT=3001` 需要与原生服务保持一致，
   并继续只绑定本地回环。
3. `.cloakbrowser` 目录权限和挂载语义需要原样保留。
4. NFS `/mnt/storage` 整根挂载不能拆成子目录，否则 hardlink 导入失效。
5. `rock5c` 的 SOCKS5 代理环境、`--add-host`、插件健康恢复 timer 需要
   迁移到原生 systemd service。
6. Dex OIDC 回调 `https://moviepilot.rock5c.zhyi.cc/api/v1/plugin/OidcAuth/callback`
   必须回归。

## 结论

生产 `rock5c` 暂不直接切换。先在 lubancat 用临时 `CONFIG_DIR` 启动原生
`moviepilot`，验证进程、`/api/v1/system/version`、登录与前端静态资源；
通过后再决定是否切 rock5c。
