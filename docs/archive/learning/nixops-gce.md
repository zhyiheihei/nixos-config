# nixops-gce 学习笔记

## 1. 是什么

`nixops-gce` 是 NixOps 的 Google Cloud（GCP）后端插件：让
`deployment.targetEnv = "gce"` 的机器和 GCE 资源由 NixOps 声明式
管理。作者 Evgeny Egorochkin，维护者 Amine Chikhaoui，25 star，
pyproject 标注 MIT（仓库没有 LICENSE 文件），Python，2023-08 后
基本停更。

依赖：

- `apache-libcloud`（GCE driver）+ 固定 `cryptography` 版本；
- nixops（git master）；
- `nixos-modules-contrib`（git master）。

## 2. 资源与后端

`nixops_gcp/resources/` 实现 GCP 资源：

- gce_disk / gce_image / gce_network / gce_route；
- gce_static_ip / gce_forwarding_rule / gce_target_pool /
  gce_http_health_check；
- gse_bucket（GCS 存储桶）。

每个资源分 `resources/<name>.py`（state）和
`resources/types/<name>.py`（选项类型）；`gcp_common.py` 提供
`ResourceDefinition` / `ResourceState` 基类、libcloud 连接、
镜像查找（按 name 或 family）等公共逻辑。

`backends/gce.py` 是机器后端：

- `GCEDefinition`：machineName、region、instanceType、service
  account（email + scopes）、scheduling（preemptible 等）、labels、
  blockDeviceMapping、bootstrapImage；
- `GCEDefinition` 用 libcloud 创建实例/磁盘，状态用
  `attr_property` 持久化，SSH 走生成的 key pair + known_hosts。

## 3. Nix 侧模块

`nixops_gcp/nix/` 定义选项和资源模板：

- `common-gce-options.nix` / `gce-credentials.nix`；
- `gce.nix`：机器选项 + 实现（`deployment.targetEnv == "gce"`）；
- 每个资源一个 `.nix`（disk/image/network/route/static-ip/
  forwarding-rule/target-pool/http-health-check/bucket）。

插件注册：`plugin.py` 返回 `NixopsGCPPlugin`
（`nixexprs` → nix 目录，`load` → resources + backends.gce）；
poetry entry point 把 `gcp` 注册进 NixOps。

## 4. 测试与工程

- `tests/functional/`：`single_machine_gce_base.nix`、
  `single_machine_static_ip_gce.nix`（静态 IP 机器示例）；
- `examples/`：trivial、custom-image、machine-with-disk、route、
  forwarding-rule、simple-web-server、rmq；
- dev：`nix-shell` + `poetry install`，跑 black/mypy（mypy 对
  libcloud 忽略 missing imports）；
- 无 GitHub Actions。

## 5. 对我们仓库的启发

- 我们用 colmena、不用 NixOps，且没有 GCP 主机，不引入；
- 它和 nixops-libvirtd（已学）是同一套后端插件结构：Nix module
  选项 + Python ResourceState + poetry plugin 注册；
- 资源建模（disk/image/network/ip 分开成资源、机器引用）适合做
  云资源声明式工具时参考。

## 6. 参考

- [nixops-gce](https://github.com/nix-community/nixops-gce)
