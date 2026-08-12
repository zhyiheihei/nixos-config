# 调研文档 07：与作者上游的偏移情况

> 日期：2026-08-12。对照对象：`../nixos-config-exam`，HEAD
> `8c63253c`；本仓库 HEAD `15ab58a8`。

## 总体

| 目录 | 共有文件有差异 | 本仓库独有 | 上游独有 |
| --- | ---: | ---: | ---: |
| `nixos/optional-apps` | 102 | 23 | 2 |
| `hosts` | 3 | 13 | 25 |
| `nixos/` 其他公共模块 | 73 | 若干自有硬件/主机 | 若干上游主机 |

## 允许的偏移

- 域名：`zhyi.xin` / `zhyi.cc` / `moliy.site` 代替 `lantian.pub` 等。
- 用户：`zhyi` 代替 `lantian`。
- 自有主机：`router`、`cnvm`、`jpvm`、`opi5p`、`rock5c`、
  `lubancat1`、`h28k`、`ml-builder` 等。
- 自有服务：`sublinkpro`、`filecodebox`、`memos`、`metacubexd`、
  `home-assistant`、`moviepilot`、`sun-panel`、`vertex` 等，上游无对应模块。

## 本次任务新增的偏移（均有对应宿主配置或独立模块）

- `nixos/optional-apps/sublinkpro-nix.nix`
- `nixos/optional-apps/filecodebox-nix.nix`
- `nixos/optional-apps/memos-nix.nix`
- `nixos/optional-apps/sun-panel-nix.nix`
- `nixos/optional-apps/waline/default.nix`：对齐上游 Nix systemd 实现，
  仅域名/站点信息不同
- `patches/waline-fix-avatar.patch`、`patches/waline-force-load-config.patch`
- 调研文档 `05`、`06`

## 合规确认

- 未修改作者上游的公共模块；涉及的上游同名文件只有 `waline`，且对齐了
  上游实现，只替换域名与站点信息。
- 上游使用 podman 的服务保持 podman；本仓库新增的原生模块均为独立文件。
