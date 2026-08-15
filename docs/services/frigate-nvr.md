# Frigate NVR 使用手册

最后整理：2026-08-15。Frigate 跑在 opi5p，管理两台乐橙（华橙网络）摄像头，
连续录像 7 天存 QNAP NAS。

## 摄像头清单

| 名称 | 位置 | IP | MAC | 型号 | 本地用户/密码 |
| --- | --- | --- | --- | --- | --- |
| `bedroom` | 卧室 | `192.168.0.104` | `1c:4d:89:e1:2a:b5` | LC-TA3R-8Q1S | `admin` / secrets `frigate.yaml` 的 `bedroom-pw` |
| `livingroom` | 客厅 | `192.168.0.115` | `1c:4d:89:e3:4e:3a` | LC-DK2-3H1W | `admin` / secrets `frigate.yaml` 的 `livingroom-pw` |

- 两台摄像头在 router 的 Kea DHCP 中已绑定静态预留
  （`hosts/router/dhcp.nix`），IP 不会漂移。
- 识别依据：ONVIF WS-Security 认证（用户名 `admin`，密码与房间一一对应），
  卧室密码只被 `.104` 接受，客厅密码只被 `.115` 接受。

## 服务入口

| 项 | 值 |
| --- | --- |
| Web UI | `http://frigate.opi5p.zhyi.cc`（**仅内网可达**，`accessibleBy = private`，HTTP） |
| 录像存储 | QNAP NAS → opi5p NFS → `/mnt/storage/surveillance/frigate`（bind 到 `/var/lib/frigate`） |
| SQLite 数据库 | opi5p 本机 `/nix/persistent/var/lib/frigate/frigate.db`（不在 NAS，避免 NFS 锁问题） |
| 保留策略 | 连续录像 7 天；告警/检测片段各 7 天 |
| 检测器 | CPU（RK3588 八核，2 路足够；Rockchip NPU 暂无主流支持） |

## 架构说明

```
乐橙摄像头 (RTSP/ONVIF, 192.168.0.104/.115)
   │
   ├─ RTSP 拉流 ──> frigate (opi5p)
   │                   ├─ 检测/录像（ffmpeg → /var/lib/frigate → NAS NFS）
   │                   └─ go2rtc（模块自带，Web UI 实时预览）
   └─ ONVIF 控制（云台/快照等）

浏览器 ──> frigate.opi5p.zhyi.cc (内网私有 vhost)
              └─> nginx frigate.localhost (127.0.0.1:13568)
```

- nixpkgs 的 `services.frigate` 模块自带 nginx vhost 处理 `/auth`、`/vod`、
  `/live` 等内部路径；该 vhost 只监听回环端口 13568（`LT.port.Frigate`），
  不直接对外。
- 公开名 `frigate.opi5p.zhyi.cc` 由 `lantian.nginxVhosts` 声明，仅内网
  （reserved IP + localhost）可达，HTTP-only，对齐
  `tachidesk-backend.opi5p.zhyi.cc` 的做法。
- 摄像头本地密码通过 sops 解密到 `/run/secrets`，再渲染成
  `/run/frigate-env`（EnvironmentFile），frigate 启动时用 `{FRIGATE_*}`
  占位符替换进 `frigate.yml`；密码不落 Nix store。

## 日常使用

1. 浏览器打开 `http://frigate.opi5p.zhyi.cc`，用 Frigate 自带账号登录
   （首次部署后需要在 UI 里创建用户）。
2. 实时预览：Live 页签；历史回放：Recordings 页签按时间线回放。
3. 检测：默认 CPU 检测人/车等对象，Events 页签可筛选告警片段。
4. Home Assistant（同机 opi5p）：添加集成 → Frigate，URL 填
   `http://127.0.0.1:5001`，按 HA 提示提供 Frigate 用户/API key，摄像头
   实体即可进入 HA dashboard。Frigate 与 HA 同机，不依赖 MQTT。

## 故障排查

| 现象 | 处理 |
| --- | --- |
| 摄像头显示 Offline / 拉流失败 | 检查 RTSP 是否在乐橙 App 里开启（设备设置 → 本地接入/RTSP）；`ssh -p 2222 root@opi5p` 后用 `journalctl -u frigate -e` 看 ffmpeg 报错 |
| 录像为空 | `df -h /mnt/storage` 确认 NFS 挂载；`ls /var/lib/frigate/recordings` 确认落盘 |
| Web UI 打不开 | `systemctl status frigate go2rtc nginx`；确认 `frigate.localhost` vhost 在 127.0.0.1:13568 |
| 401 | 用户名/密码错误；检查 `sops --decrypt frigate.yaml` 里的值是否与 App 一致 |

## 改动与部署

- 模块：`nixos/optional-apps/frigate.nix`（opi5p 手动导入）。
- 摄像头密码：`nixos-secrets/frigate.yaml`（SOPS），改后推送并
  `nix flake update secrets`。
- 构建部署（ml-builder）：

  ```bash
  cd /nix/src/nixos-config && git pull --ff-only
  nix run .#colmena -- build --on opi5p
  nix run .#colmena -- apply --on opi5p
  ```

- 已知限制：RTSP 本地流需要在乐橙 App 中开启后生效；Frigate 主分支暂无
  Rockchip NPU 检测（CPU 检测已够用），后续可评估 rkmpp 硬解。
