# NixOS 模块分层与参数归属规范

> 本文是 [`work-norms.md`](./work-norms.md) 的补充细则。任何新增、调整模块、
> 容器、代理、数据库接入或主机编排前，先按本文核对位置。

## 1. 模块放哪里

- 通用、可复用的 NixOS 模块放在 `nixos/optional-apps/`，或按角色放在
  `nixos/<role>-apps/`、`nixos/<role>-components/` 等目录。
- 新模块必须提供 `options.lantian.<name>`，并只在 `config = lib.mkIf cfg.enable`
  中启用，不能写成导入即生效的裸配置。
- `hosts/<host>/` 只负责 import、enable 选项、主机级覆盖和链路编排聚合。
- 禁止在 `hosts/` 层直接定义通用服务模块；禁止在公共 `nixos/` 模块写死主机
  专属值。
- 新增能力要独立成模块，不修改作者原版已有的公共模块。

## 2. 主机专属参数放哪里

- 代理与环境变量：`hosts/<host>/configuration.nix` 中针对具体
  `systemd.services.<unit>.environment` 设置。
- 存储路径：模块 `options` 提供默认值，主机按需覆盖。
- 端口：统一登记在 `helpers/constants/ports.nix`。
- Nginx vhost：通用模块内可用 `config.networking.hostName` 派生；主机专属
  入口放主机配置。
- 参数位置按职责归属，不按“能跑就行”摆放。

## 3. 代理规则

- 公共 `nixos/` 模块不得写 `HTTP_PROXY`、`HTTPS_PROXY`、`NO_PROXY` 等代理变量。
- 主机代理只允许在 `hosts/<host>/configuration.nix` 对具体 systemd 服务设置。
- 覆盖代理时合并单项，禁止 `lib.mkForce` 整个 `environment`，否则会丢掉
  systemd/podman 需要的 `PATH` 等变量。
- 容器内 PySocks 使用 `socks5` 会在本地解析域名；解析异常时改用
  `socks5h://`，让代理远端解析。
- GitHub 等外站默认走代理，不因为直连偶尔可用就改成直连。

## 4. Podman 容器规范

- 使用官方镜像，设置 `autoStart = true` 和
  `labels."io.containers.autoupdate" = "registry"`。
- 对外监听端口绑定 `127.0.0.1`，不直接暴露到局域网/公网。
- 有状态数据放 `/nix/persistent/...`，容器内通过 volume 挂载。
- 容器代理由主机层 systemd 服务注入，不写进公共容器模块。
- 不依赖自有 Nix 包时，优先使用官方容器镜像，避免为包依赖反复补丁。

## 5. 数据库与 API

- 不修改现有数据库；新服务使用自己的 SQLite/数据库文件。
- 站点、下载器、媒体库等配置通过官方 API/UI/CLI 完成，不手工改数据库。
- 部署和迁移过程中不写旧服务的数据库。

## 6. 并行与回滚

- 新链路先并行运行，旧服务保持 active，直到验收通过再切换。
- 激活门闩/ready marker 与目标主机保持一致。
- 构建只在 `ml-builder` 执行；部署前先 build，再按主机 apply。
- 切换前保留旧配置和旧数据，确保可回滚。

## 7. 提交前审计命令

```bash
# 公共模块不得出现代理变量
rg -n 'HTTP_PROXY|HTTPS_PROXY|http_proxy|https_proxy|NO_PROXY|no_proxy' nixos/ --glob '*.nix'

# hosts 层不得定义 options
rg -n 'options\.' hosts/ --glob '*.nix'

# 公共模块不得整环境 mkForce
rg -n 'environment = .*mkForce' nixos/ --glob '*.nix'

# 容器必须有 autoupdate label
rg -n 'io.containers.autoupdate' nixos/optional-apps/ --glob '*.nix'
```

审计结果出现违规时，先修位置和归属，再提交。
