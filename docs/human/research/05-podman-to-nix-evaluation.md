# 调研文档 05：Podman 容器能否用 Nix 包替代

> 日期：2026-08-11。范围：`nixos-config` 中通过
> `virtualisation.oci-containers` 或 `podman run` 使用的服务。
> 结论带 nixpkgs/NUR 实测，不依赖“应该有”的猜测。

## 结论

1. 已经有 Nix 包或本仓库包可直接替代的：`home-assistant`、`memos`、
   `metacubexd`、`halo`、`handbrake`、`freshrss`、`linkwarden`、
   `archisteamfarm`（asf）、`bazarr`（byparr）、`waline`（NUR xddxdd）；
   `moviepilot`、`filecodebox`、`sun-panel`、`vertex` 已在 zhyi-packages。
2. 本次新增到 zhyi-packages 的两个可替代容器：
   - `sublinkpro`：官方 release 单文件二进制，已收录
     `pkgs/uncategorized/sublinkpro`；
   - `tachidesk-server`：官方 Suwayomi jar + JRE 包装，已收录
     `pkgs/uncategorized/tachidesk-server`。
3. 保留容器的主要是三类：依赖硬件设备树/GPU/Android 用户态的
   （redroid、immich-rknn、sglang），上游只有镜像没有可稳定打包源码的
   （mmrelay、archiveteam），或依赖 Chromium/Django 全链路的重量级应用
   （archivebox）。
4. `torrentool` 保留在 zhyi-packages：MoviePilot 硬依赖它，而 NUR 校验
   不能消费另一个 NUR 仓库作为 flake 输入，直接移除会让
   `test-nur-eval` 失败。

## 已完成的替换测试

| 服务 | 主机 | 状态 | API 验证 |
| --- | --- | --- | --- |
| `sublinkpro` | greencloud | 原生包运行，podman 停 | version/login/nodes/subcription/shares/静态订阅均 200 |
| `filecodebox` | opi5p | 原生包运行，podman 停 | `/health`、上传初始化接口、vhost 200 |
| `memos` | opi5p | 原生包运行，podman 停 | `/healthz`、`/api/v1/memos`、登录接口 |
| `sun-panel` | opi5p | 原生包运行，podman 停 | `/api/about`、登录接口 |

## 不可完整替代的复核

- `metacubexd`：nixpkgs `metacubexd` 只是 Clash.Meta 官方 Dashboard
  （`meta.description = "Clash.Meta Dashboard, The Official One, XD"`），
  不含当前容器里的 mihomo 服务端；因此保留 podman。
- `moviepilot`：原生包已在 lubancat 完成启动/API 验证，但 `moviepilot
  start` 只有后台 daemon 语义，systemd 无法直接获得稳定重启语义；生产
  `rock5c` 保留 podman，详见
  [06-moviepilot-nix-replacement-impact.md](06-moviepilot-nix-replacement-impact.md)。
- `home-assistant`：当前容器 `--privileged`、host 网络并挂载 `/dev` 与
  `docker.sock`；nixpkgs `services.home-assistant` 默认不提供等价能力，
  未做生产切换前保留 podman。

## 已对齐上游的服务

- `waline`：上游作者本身就是 Nix systemd 服务，本仓库已改为相同的
  `pkgs.nur-xddxdd.waline` 实现（含两个上游补丁），域名保持 zhyi 侧。

## 2026-08-11 实机运行审计

审计方式：子代理 SSH 到各主机执行 `systemctl`、`podman ps` 与
`systemctl --failed`，只记录原始输出。

2026-08-12 服务迁移后，pve-5700u 的三个 x86-only 容器已随 Hydra 一并迁到
`ml-builder`；下表位置按迁移后的当前归属更新。

| 主机 | 运行中的 podman 容器 | 失败 unit | 未运行但已定义的服务 |
| --- | --- | --- | --- |
| `rock5c` | `moviepilot`、`handbrake`、`metacubexd`、`immich-machine-learning-rknn`、`chinesesubfinder` | 0 | `sonarr`、`radarr`、`bazarr`、`prowlarr`（已迁移/停用） |
| `opi5p` | `archivebox`、`asf`、`filecodebox`、`home-assistant`、`memos`、`sun-panel`、`sun-panel-helper`、`tachidesk` | 0 | `vertex`、`byparr`、`redroid`、`immich-machine-learning`（迁移中或已停用） |
| `greencloud` | `byparr`、`pyison`、`sublinkpro` | 0 | 无 |
| `ml-builder` | `archiveteam`、`clawemail`、`epic-awesome-gamer` | 0 | `halo`、`waline`（未定义） |
| `pve-5700u` | 无 | 0 | 无 |

结论：当前生产主机上的 podman 服务运行正常、无失败 unit；但这不等于
“完美取代 podman”。可替代服务（如 `sublinkpro`、`tachidesk`、
`moviepilot`、`filecodebox`、`sun-panel` 等）仍以容器方式运行，Nix 包只
通过了构建与单机冒烟测试，尚未接入 `hosts/*` 配置并完成数据迁移；
`redroid`、`immich-rknn`、`sglang`、`archivebox` 等依赖硬件/重量级运行链，
明确保留容器。

## 明细

| 容器 / 服务 | 上游镜像 | 现位置 | 来源检查 | 结论 |
| --- | --- | --- | --- | --- |
| `home-assistant` | ghcr.io/home-assistant | opi5p | nixpkgs `home-assistant` | 可替换 |
| `memos` | docker.io/neosmemo | opi5p | nixpkgs `memos` | 可替换 |
| `metacubexd` | ghcr.io/metacubex | rock5c | nixpkgs `metacubexd` | 可替换 |
| `halo` | docker.io/halohub | pve/opi5p | nixpkgs `halo` | 可替换 |
| `handbrake` | emcd39 / zocker160 | rock5c | nixpkgs `handbrake` | 基础可替换，硬件变体仍看驱动 |
| `asf` | ghcr.io/justarchinet | opi5p | nixpkgs `archisteamfarm` | 可替换 |
| `byparr` | ghcr.io/thephaseless | greencloud | nixpkgs `bazarr` | 可替换 |
| `waline` | docker.io/lizheming | pve/opi5p | NUR xddxdd | 可替换 |
| `moviepilot` | docker.io/jxxghp | rock5c | zhyi-packages | 已收录 |
| `filecodebox` | docker.io/lanol | opi5p | zhyi-packages | 已收录 |
| `sun-panel` + helper | docker.io/hslr | opi5p | zhyi-packages | 主面板已收录 |
| `vertex` | docker.io/lswl | opi5p | zhyi-packages | 已收录 |
| `sublinkpro` | docker.io/zerodeng | greencloud | zhyi-packages（新增） | 已收录 |
| `tachidesk` | ghcr.io/suwayomi | opi5p | zhyi-packages（新增） | 已收录 |
| `freshrss` | docker.io/freshrss | opi5p | nixpkgs `freshrss` | 可替换（当前已退役） |
| `linkwarden` | ghcr.io/linkwarden | opi5p | nixpkgs `linkwarden` | 可替换（当前已退役） |
| `archivebox` | docker.io/archivebox | opi5p | 无 nixpkgs/NUR | 保留容器：Django + Chromium 链路过重 |
| `archiveteam` | atdr.meo.ws | ml-builder | 无 nixpkgs/NUR | 保留容器：warrior 运行框架 |
| `clawemail` | ghcr.io/wangxingfan | ml-builder | 无 nixpkgs/NUR | 有源码，待打包（Node + better-sqlite3） |
| `epic-awesome-gamer` | ghcr.io/qin2dim | ml-builder | 无 nixpkgs/NUR | 有源码，待打包（Python + xvfb） |
| `immich-machine-learning-rknn` | immich release-rknn | opi5p/rock5c | 无 nixpkgs/NUR | 保留容器：RKNN 驱动/设备树绑定 |
| `redroid` | cnflysky / local | opi5p/opi03 | 无 nixpkgs/NUR | 保留容器：Android 内核用户态 |
| `mmrelay` | ghcr.io/jeremiah-k | 家庭 | 无 nixpkgs/NUR | 保留容器：上游源码未稳定定位 |
| `pyison` | ghcr.io/jonaslong | 家庭 | 无 nixpkgs/NUR | 有源码，待打包（需 nltk 数据） |
| `sglang-sakura-llm` | lmsysorg | 家庭 | 无 nixpkgs/NUR | 保留容器：CUDA/模型运行时 |
| `adsb-plane-watch` / `adsb-flightaware` | plane-watch / piaware | 家庭 | 无 nixpkgs/NUR | 保留容器：硬件 + 固件封装 |
| `lancache-dns` / `lancache-monolithic` | lancachenet | 家庭 | 无 nixpkgs/NUR | 保留容器：整体缓存栈 |
| `bilibili-tool-pro` | ghcr.io/raywangqvq | 定时任务 | 无 nixpkgs/NUR | 有源码，待打包（.NET） |

## 方法

- nixpkgs 检查：ml-builder 上对每个候选执行
  `nix eval --raw nixpkgs#<attr>.pname`。
- NUR 检查：对照 `nix-community/NUR` 的 milahu / xddxdd 仓库实际包定义。
- 上游检查：`gh api` 读取 release 资产和官方 digest，避免下载大文件猜哈希。
- 本仓库包元数据由 `pkgs/_meta/readme` 生成，README 不手工维护。

## 来源

- https://github.com/ZeroDeng01/sublinkPro
- https://github.com/Suwayomi/Suwayomi-Server
- https://github.com/idlesign/torrentool
- https://github.com/nix-community/NUR
- https://github.com/milahu/nur-packages
