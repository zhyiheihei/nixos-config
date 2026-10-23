# dragon-q8b（ARM SBC，8 GiB）

NCPS 缓存源站 + 家庭工具宿主（archivebox、redroid、bitmagnet 等）。
`hosts/dragon-q8b/*.nix` 不写注释，理由记录在本文件。

## NCPS（集群唯一的 substituter）

- `ncps` 的替代下载（对上游仓库的按需代理）曾走 router V2Ray
  （`LT.proxyEnvironment`），该路径 2026-09-05 间歇性断流，导致 NCPS 替代下载超时、
  全集群 substituter 退化。改走 rock5c 上的 metacubexd mihomo mixed 口
  （`metacubexd.nix` 里 `MIXED_PORT=7892`，发布在 rock5c LAN 地址上）。m-team 豁免
  照旧。
- 部署前必须先确认 NCPS 可用（它是本机唯一 substituter，见
  [deployment](../deployment.md)）。

## redroid / Android 容器

- 官方 redroid 镜像没有 GMS，用 MindTheGapps 13 arm64 官方包叠加出本地镜像。
- MTG 附带的 GMS setup wizard 不适合 headless 容器（见 redroid-doc 的 GApps 章节），
  构建时剥掉。
- 镜像构建服务缺基础镜像时需要拉网，代理注入对齐 redroid 容器服务自身。
- `nomodeset` 会让 msm DRM 拒绝 probe（`adev bind failed -19`），而 kernelParams 只能
  追加、`mkForce` 重列会顶掉模块级参数，所以整块用 `disabledModules` 禁用。

## 存储与网络

- `/mnt/storage` 是 QNAP NFS，archivebox 绑定其中；`noauto` + automount 同 opi5p
  （`c72df01ca`）。通用策略禁用全局 wait-online，NFS 挂载依赖按接口实例等待。
- `host.nix` 的地域字段即使没有 dn42，server-role 的 BIRD 配置也会读取。

## picoclaw

- 按上游停用（`pve-epyc` 注释该模块），用户 2026-10-22 要求跟随：模块 import 与
  `./picoclaw-config.nix` 都停用。
- 本机 `/` 是 tmpfs，picoclaw 的 `config.json` 无法跨重启存活；开机用 picoclaw 专用
  key 拼装种子配置（缺文件或缺目标模型就重写，`healed` 后的运行期改动保留）。
