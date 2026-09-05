# Frigate NVR 使用手册

最后整理：2026-08-15。Frigate（Rockchip 专版）跑在 opi5p，用 RKNN NPU 检测，
管理两台乐橙（华橙网络）摄像头，连续录像 7 天存 QNAP NAS。

## 摄像头清单

| 名称 | 位置 | IP | MAC | 型号 | 本地用户/密码 |
| --- | --- | --- | --- | --- | --- |
| `bedroom` | 卧室 | `192.168.0.104` | `1c:4d:89:e1:2a:b5` | LC-TA3R-8Q1S | `admin` / secrets `frigate.yaml` 的 `bedroom-pw` |
| `livingroom` | 客厅 | `192.168.0.115` | `1c:4d:89:e3:4e:3a` | LC-DK2-3H1W | `admin` / secrets `frigate.yaml` 的 `livingroom-pw` |

- 两台摄像头在 router 的 Kea DHCP 中已绑定静态预留（`hosts/router/dhcp.nix`），IP 不会漂移。
- 识别依据：ONVIF WS-Security 认证（用户名 `admin`），卧室密码只被 `.104` 接受，客厅密码只被 `.115` 接受。

## 服务入口

| 项 | 值 |
| --- | --- |
| Web UI | `https://frigate.opi5p.zhyi.xin`（**仅内网可达**，`accessibleBy = private`，HTTPS 用 `*.<hostname>.zhyi.xin` 通配证书） |
| 容器 | `ghcr.io/blakeblackshear/frigate:stable-rk`（官方 Rockchip 专版，含 RKNN 支持） |
| 录像存储 | QNAP NAS → opi5p NFS `/mnt/storage/surveillance/frigate` → 容器 `/media/frigate` |
| 配置/数据库 | opi5p 本机 `/nix/persistent/var/lib/frigate` → 容器 `/config` |
| 保留策略 | 连续录像 7 天；告警/检测片段各 7 天 |
| 检测器 | RKNN（NPU），默认模型 `deci-fp16-yolonas_s`（rk3588 上约 25ms/帧），自动下载到 `/config/model_cache/rknn_cache` |

## 架构说明

```
乐橙摄像头 (RTSP/ONVIF, 192.168.0.104/.115)
   │
   ├─ RTSP 拉流 ──> frigate 容器 (opi5p, --network=host)
   │                   ├─ RKNN 检测（/dev/dri renderD128 = rknpu 驱动 v0.9.8）
   │                   ├─ 录像（ffmpeg → /media/frigate → NAS NFS）
   │                   └─ go2rtc（容器内置，实时预览）
   └─ ONVIF 控制

浏览器 ──> frigate.opi5p.zhyi.xin（内网私有 vhost）
              └─> 127.0.0.1:8971（frigate web，host 网络）
```

- 官方文档的 Rockchip 方案要求：BSP 内核 + rknpu 驱动 ≥ v0.9.2、`/dev/dri`、
  `/dev/dma_heap`、`/dev/rga`、`/dev/mpp_service`、`/sys` 只读挂载、
  `systempaths=unconfined`——模块 `frigate-rockchip.nix` 已全部配置，
  与项目 immich-rknn-worker 容器的做法一致。
- 模块是通用 Rockchip 专版（`nixos/optional-apps/frigate-rockchip.nix`），
  任何带 RKNPU 的 RK 板（RK3566/3568/3588，如 lubancat1、r5c、rock5c）都可
  启用；每个摄像头只需在主机配置里加 `rtspUrl` + `onvifHost`，密码 key 为
  secrets `frigate.yaml` 中的 `<camera>-pw`。
- `config.yml` 由 sops 模板渲染，摄像头密码在解密时直接替换进文件，
  不落 Nix store。
- **配置渲染必须用模块自制的块状 toYaml**：nixpkgs 的
  `lib.generators.toYAML` 实为 `toJSON`，flow 风格会被保留——frigate 的
  `create_config.py` 用 ruamel 加载 config.yml 后重新转储 go2rtc 段，
  JSON flow 风格里含 `?`/`&` 的 RTSP URL 不加引号直接破 YAML 语法，
  go2rtc 一条流都加载不到（2026-09-04 实证）。模板变更时自动重启容器
  （`restartUnits`）：`create_config.py` 只在启动时把 config.yml 转储成
  `/dev/shm/go2rtc.yaml`，不重启不生效。
- sops 模板渲染结果是符号链接，容器内 /run 不同会断链，容器启动前由
  `podman-frigate` 的 ExecStartPre 先删旧链接再装成真实文件；容器依赖
  `sops-install-secrets.service`（注意服务名不是 sops-nix.service）。
- 预设模型（`<model>-<soc>-v2.3.2-2.rknn`）由 nix `fetchurl` 预取并铺进
  `model_cache/rknn_cache`，确定性、无运行时网络依赖；自定义路径模型
  （含 `/`）不预取，运行时需自行就位。容器内**不配代理**（模型已预取、
  RTSP/ONVIF 走内网；且 frigate 的 urllib 模型下载不认 socks5）。
- `version = "0.17-0"` 显式声明配置版本，避免 frigate 误认为 0.13 旧配置
  每次启动都迁移。
- 为什么用官方镜像而不是 nixpkgs 原生包：nixpkgs frigate 依赖
  tensorflow-bin，aarch64 的 tensorflow/tf-keras 2.21 在任何可达缓存中都不
  存在（qemu 交叉编译又在 imports check 崩溃）；且 RKNN 需要 python 3.12
  的 rknnlite（无 cp313 wheel）。`stable-rk` 镜像自带 python 3.12 +
  rknn-toolkit-lite2 + 各 SoC 的预编译 RKNN 模型下载，是官方唯一文档化的
  Rockchip 方案。

## 日常使用

1. 浏览器打开 `https://frigate.opi5p.zhyi.xin`（仅内网）。认证走统一身份链：
   oauth2-proxy → Dex（`login.zhyi.xin`）→ Pocket ID（`id.zhyi.xin`）Passkey
   登录；frigate 本体不设密码（`auth.enabled=false`，用户/角色由反代 header
   透传，`default_role=admin`）。
2. 实时预览：Live 页签；历史回放：Recordings 页签按时间线回放。
3. 检测：RKNN NPU 检测（YOLO-NAS），当前只跟踪猫，Events 页签筛选告警片段。
4. Home Assistant（同机 opi5p）：添加集成 → Frigate，URL 填
   `http://127.0.0.1:5000`（容器 api 端口），按 HA 提示提供 Frigate 用户/
   API key。不依赖 MQTT。

> 反代说明：frigate 0.17 的 Web 是 HTTPS-only（容器自签证书），内网 vhost
> 以 `https://127.0.0.1:8971` + `proxy_ssl_verify off` 反代，对外是
> `https://frigate.opi5p.zhyi.xin`（`*.<hostname>.zhyi.xin` 通配证书）。
> 认证由 oauth2-proxy 在 nginx 层强制（`enableOAuth`），frigate 本体关闭
> 认证（`auth.enabled=false`），经 `proxy.header_map` 透传 `X-User`/`X-Groups`。

## 故障排查

| 现象 | 处理 |
| --- | --- |
| 摄像头 Offline / 拉流失败 | 检查 RTSP 是否在乐橙 App 里开启（设备设置 → 本地接入/RTSP）；`journalctl -u podman-frigate -e` 看 ffmpeg 报错 |
| 检测器报 rknn 错误 | 确认 `/dev/dri` 存在（rknpu 驱动）、`cat /sys/kernel/debug/rknpu/version` ≥ 0.9.2；模型在 `/config/model_cache/rknn_cache` |
| 模型下载失败 | 模型由 nix 预取（构建期），容器内不再联网下载；确认 `model_cache/rknn_cache/<model>-<soc>-v2.3.2-2.rknn` 存在 |
| 录像为空 | `df -h /mnt/storage` 确认 NFS；容器内 `ls /media/frigate/recordings` |
| Web UI 打不开 | `systemctl status podman-frigate nginx`；frigate web 应监听 127.0.0.1:8971 |
| 401 | 摄像头用户名/密码错误；检查 `sops --decrypt frigate.yaml` 与 App 一致 |

## 改动与部署

- 模块：`nixos/optional-apps/frigate-rockchip.nix`；主机接入在
  `hosts/opi5p/configuration.nix` 的 `lantian.frigate`。
- 摄像头密码：`nixos-secrets/frigate.yaml`（SOPS），改后推送并
  `nix flake update secrets`（在 ml-builder 上执行，本机无 GitHub API 认证）。
- 构建部署（ml-builder）：

  ```bash
  cd ~/Documents/nixos/nixos-config && git pull --ff-only
  nix run .#colmena -- build --on opi5p
  nix run .#colmena -- apply --on opi5p
  ```

- 已知限制：乐橙 App 中默认开启 **RTSP 加密（TLS）**，frigate 直连会拉流失败；
  需在 App 设备设置里关闭 RTSP 加密后，本地 RTSP 才能被 frigate 消费
  （两台均已关闭，2026-08-16 验证正常）。

## Home Assistant 集成

Frigate 集成组件（frigate-hass 5.15.4，声明式打包）+ 本机 mosquitto（127.0.0.1:1883）
已部署；frigate 事件走 MQTT 推送。在 HA UI 中添加两个集成：

1. **MQTT**：设置 → 设备与服务 → 添加集成 → MQTT → broker `127.0.0.1:1883`，无认证
2. **Frigate**：设置 → 设备与服务 → 添加集成 → Frigate →
   URL `http://127.0.0.1:5000`（内部未认证端口，无需用户名/密码）

添加后 HA 会获得：
- **摄像头实体**（`camera.bedroom` / `camera.livingroom`）：直播流来自模块
  生成的同名 go2rtc restream（`rtsp://<host>:8554/<camera>`，host 网络），
  缺了 HA 里只能看快照；实时画面经 hass-web-proxy-lib 反代
- **猫检测传感器**（`binary_sensor.bedroom_cat` 等，走 MQTT 实时更新）
- Frigate 事件/媒体浏览器集成

## 猫识别与跟踪

- `objects.track = ["cat"]`（COCO labelmap 自带 cat 类），`filters.cat`：
  `threshold 0.7`（事件判定）、`min_score 0.5`（过滤低置信度）；要同时
  跟踪人/车再加进 track 列表
- 自定义分类「毛豆」：子标签方式（`classification.custom`），置信度 ≥0.8
  的 cat 检测被打上毛豆子标签，HA 里可按子标签过滤
- 事件快照已开启（`snapshots.enabled`，保留 7 天；HA 摄像头实体缩略图与
  事件时间线用），frigate Events 页签可按 cat 筛选
- RKNN NPU 检测（yolonas_s，rk3588 上约 25ms/帧）
- PTZ 自动跟踪（ONVIF RelativeMove）选项保留但未启用：两台乐橙
  （TA3R/DK2）实测不支持相对移动（云台物理不动、校准 slope≈0），只保留
  手动 PTZ 与猫检测告警
