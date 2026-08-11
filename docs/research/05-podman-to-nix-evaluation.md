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

## 2026-08-11 实机运行审计

审计方式：子代理 SSH 到各主机执行 `systemctl`、`podman ps` 与
`systemctl --failed`，只记录原始输出。

| 主机 | 运行中的 podman 容器 | 失败 unit | 未运行但已定义的服务 |
| --- | --- | --- | --- |
| `rock5c` | `moviepilot`、`handbrake`、`metacubexd`、`immich-machine-learning-rknn`、`chinesesubfinder` | 0 | `sonarr`、`radarr`、`bazarr`、`prowlarr`（已迁移/停用） |
| `opi5p` | `archivebox`、`asf`、`filecodebox`、`home-assistant`、`memos`、`sun-panel`、`sun-panel-helper`、`tachidesk` | 0 | `vertex`、`byparr`、`redroid`、`immich-machine-learning`（迁移中或已停用） |
| `colocrossing` | `byparr`、`pyison`、`sublinkpro` | 0 | 无 |
| `pve-5700u` | `archiveteam`、`clawemail`、`epic-awesome-gamer` | 0 | `halo`、`waline` |

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
| `byparr` | ghcr.io/thephaseless | colocrossing | nixpkgs `bazarr` | 可替换 |
| `waline` | docker.io/lizheming | pve/opi5p | NUR xddxdd | 可替换 |
| `moviepilot` | docker.io/jxxghp | rock5c | zhyi-packages | 已收录 |
| `filecodebox` | docker.io/lanol | opi5p | zhyi-packages | 已收录 |
| `sun-panel` + helper | docker.io/hslr | opi5p | zhyi-packages | 主面板已收录 |
| `vertex` | docker.io/lswl | opi5p | zhyi-packages | 已收录 |
| `sublinkpro` | docker.io/zerodeng | colocrossing | zhyi-packages（新增） | 已收录 |
| `tachidesk` | ghcr.io/suwayomi | opi5p | zhyi-packages（新增） | 已收录 |
| `freshrss` | docker.io/freshrss | opi5p | nixpkgs `freshrss` | 可替换（当前已退役） |
| `linkwarden` | ghcr.io/linkwarden | opi5p | nixpkgs `linkwarden` | 可替换（当前已退役） |
| `archivebox` | docker.io/archivebox | opi5p | 无 nixpkgs/NUR | 保留容器：Django + Chromium 链路过重 |
| `archiveteam` | atdr.meo.ws | pve | 无 nixpkgs/NUR | 保留容器：warrior 运行框架 |
| `clawemail` | ghcr.io/wangxingfan | pve | 无 nixpkgs/NUR | 有源码，待打包（Node + better-sqlite3） |
| `epic-awesome-gamer` | ghcr.io/qin2dim | pve | 无 nixpkgs/NUR | 有源码，待打包（Python + xvfb） |
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
