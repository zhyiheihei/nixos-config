# Home Assistant 从 Podman 容器迁移到 Nix 原生服务

迁移日期：2026-08-15。将 `ha.opi5p.zhyi.cc` 的 Home Assistant 从
`ghcr.io/home-assistant/home-assistant:2026.3.1` Podman 容器替换为
nixpkgs `services.home-assistant` 原生服务（HA 2026.7.4）。

## 背景

容器时代 HA 的集成由 HACS 从 GitHub 下载安装，状态散落在
`/var/lib/home-assistant/custom_components/`，与 Nix 声明式管理冲突。
本次迁移把集成改为 Nix 包管理，配置目录原地复用，实体注册表、面板、
自动化与数据库历史全部保留。

## 变更内容

- `nixos/optional-apps/home-assistant.nix`：删除
  `virtualisation.oci-containers.containers.home-assistant` 容器定义，
  改为 `services.home-assistant` 原生服务。
  - `configDir = "/var/lib/home-assistant"`（复用原容器配置目录）
  - `services.avahi.hostName = "homeassistant"`：米家 OAuth 回调硬编码为
    `http://homeassistant.local:8123`（nixpkgs 官方示例要求），由 avahi
    通告该 mDNS 名，保证重登流程可用。opi5p 防火墙为 ACCEPT 策略，
    8123 无需额外放行。
  - `extraComponents`：本机有实体的核心集成（roborock / upnp / sun /
    androidtv / google_translate / shopping_list）+ 米家需要的
    `ffmpeg`、`zeroconf`。`met`、`backup` 由模块默认提供。
  - `customComponents`：
    - `pkgs.home-assistant-custom-components.xiaomi_home`（nixpkgs 自带，
      与容器中安装的 v0.4.7 一致）
    - `pkgs.dreame-vacuum`（仓库自打包，见下）
- `pkgs/dreame-vacuum/default.nix` + `overlays/57-dreame-vacuum.nix`：
  打包 Tasshack/dreame-vacuum v2.0.0b23。上游源码为 CRLF 行尾，且依赖
  `py-mini-racer`（V8 JS 封装，nixpkgs 未收录）。`prePatch` 中：
  - 统一行尾为 LF
  - 将 `from py_mini_racer import MiniRacer` 改为 try/except，缺失时
    `MiniRacer = None`
  - `optimize()` 中 `if js_optimizer:` 改为
    `if js_optimizer and MiniRacer is not None:`，缺失时走纯 Python
    地图优化回退路径（地图功能不受影响）
  - 从 `manifest.json` requirements 中移除 `mini-racer`，使 nixpkgs 的
    manifest-requirements 检查通过

## 弃用项

- **HACS**：不再使用。`custom_components/hacs` 目录迁移时移入
  `custom_components_legacy-<日期>/` 备份；`.storage/core.config_entries`
  中残留的 hacs 条目不会影响运行，可在 HA UI 中手动删除。
- 容器版 2026.3.1 → 原生 2026.7.4，配置存储向后兼容。

## 迁移步骤（已执行/部署时执行）

1. 停并删除容器：`podman stop home-assistant && podman rm home-assistant`。
2. 把 `custom_components/{hacs,xiaomi_home,dreame_vacuum}` 移到
   `custom_components_legacy-<日期>/`（三者为 HACS 下载的裸目录；xiaomi
   与 dreame 由 nix 组件替代，hacs 弃用；保留备份以便回滚）。
3. `nix build .#nixosConfigurations.opi5p.config.system.build.toplevel`
   （ml-builder），`nix run .#colmena -- apply --on opi5p`。
4. apply 后配置目录仍为 root 所有，原生服务以 `hass` 用户运行：
   `chown -R hass:hass /var/lib/home-assistant`，再
   `systemctl restart home-assistant`。

## 迁移后待办

- **米家重登**：8 月 13 日起米家云端拒绝集成凭证（access token 401 +
  refresh token 96009 invalid），迁移后仍需在 HA UI 删除并重新添加
  Xiaomi Home 集成完成 OAuth 授权（见下方）。
- 重登步骤：HA UI → 设备与服务 → 删除 `闪光丿皮皮: 2327129156 [中国大陆]`
  条目 → 添加集成 Xiaomi Home → 区域中国大陆、语言 zh-Hans、回调保持
  `http://homeassistant.local:8123/...` → 米家 App 扫码/账号登录 → 选家庭
  `闪光丿皮皮的家`。回调依赖局域网 mDNS（已由 `services.avahi.hostName =
  "homeassistant"` 保证），需在家里网络完成。
- 若 roborock 等旧条目提示重连，按 HA 提示重新登录对应账号即可。

## 后续更新方式

- **HA 核心 / 米家 xiaomi_home / 其它 nixpkgs 集成**：随 nixpkgs 更新。
  `make update`（`nix flake update` + nvfetcher）后在 ml-builder 上
  `make build` 验证，再 `nix run .#colmena -- apply --on opi5p` 部署。
  版本锁在 flake.lock，可回滚；不再有容器时代的镜像静默自动更新。
- **dreame-vacuum**：仓库内自行打包并固定 tag（`pkgs/dreame-vacuum` +
  `overlays/57-dreame-vacuum.nix`），`make update` 不覆盖它。升级流程：
  改 `pkgs/dreame-vacuum/default.nix` 的 `rev`，在 ml-builder 上
  `nix-prefetch-url --unpack --type sha256 <archive-url>` 取 base32 后
  `nix hash to-sri --type sha256` 转换填入 `hash`。注意 mini-racer
  可选化补丁（`prePatch` 中的三处 sed）需随上游代码变化同步核对。
  （曾尝试接入 nvfetcher，该版本对 git+tag 固定支持不稳定，放弃。）
- **met（挪威天气）集成**：nixpkgs 该版本未收录其依赖 `metno`，setup 失败
  属已知限制，不影响其它组件；不需要可自行在 HA UI 删除该条目。
- **hacs 残留**：`.storage/core.config_entries` 中的 hacs 条目不影响运行，
  可在 HA UI 手动删除。

## 迁移备份

容器时代的 `custom_components/{hacs,xiaomi_home,dreame_vacuum}` 原目录保留在
`/var/lib/home-assistant/custom_components_legacy-20260815/`，确认稳定后可删除。

