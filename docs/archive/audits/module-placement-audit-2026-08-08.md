# 模块分层与参数归属审计（2026-08-08）

审计基准：[`../../agent/module-placement-norms.md`](../../agent/module-placement-norms.md)。

## 审计方法

按规范文件第 7 节执行：

```bash
rg -n 'HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|NO_PROXY|no_proxy' nixos/ --glob '*.nix'
rg -n 'options\.' hosts/ --glob '*.nix'
rg -n 'environment = .*mkForce' nixos/ --glob '*.nix'
rg -n 'io.containers.autoupdate' nixos/optional-apps/ --glob '*.nix'
```

## 通过项

- `hosts/` 层没有定义 `options`。
- 公共模块没有整环境 `mkForce`。
- 所有 podman 容器均配置 `io.containers.autoupdate = "registry"`。
- rock5c 的 MoviePilot 已改为 podman 官方镜像，代理只在
  `hosts/rock5c/configuration.nix` 注入。

## 待整改项

| 文件 | 问题 | 受影响主机 |
| --- | --- | --- |
| `nixos/optional-apps/ncps.nix` | 公共模块写入 `HTTP_PROXY` / `NO_PROXY` | opi5p |
| `nixos/optional-apps/jellyfin-rockchip.nix` | 公共模块写入代理环境 | rock5c |
| `nixos/optional-apps/immich-rknn-worker.nix` | 公共模块写入代理环境 | rock5c |

## 整改方案

1. 从上述公共模块移除代理环境变量。
2. 在 `hosts/opi5p/configuration.nix` 为 `systemd.services.ncps` 注入代理。
3. 在 `hosts/rock5c/configuration.nix` 为 `systemd.services.jellyfin` 注入代理。
4. 在 `hosts/rock5c/immich-ml.nix` 为
   `systemd.services.podman-immich-machine-learning-rknn` 注入代理。

整改前先由用户确认，确认后在 ml-builder 构建，再分别 apply 受影响主机。

## 整改结果（2026-08-08）

- `ncps.nix`、`jellyfin-rockchip.nix`、`immich-rknn-worker.nix` 已移除代理变量。
- `hosts/opi5p/configuration.nix` 已为 `ncps` 注入代理，保留
  `mirror.sjtu.edu.cn` 直连 bypass。
- `hosts/rock5c/configuration.nix` 已为 `jellyfin` 和
  `podman-moviepilot` 注入代理。
- `hosts/rock5c/immich-ml.nix` 已为
  `podman-immich-machine-learning-rknn` 注入代理。
- ml-builder 构建 `opi5p,rock5c` 通过并 apply 成功；两主机服务均 active。
- 复跑审计命令：`nixos/` 公共模块中已无代理环境变量。
