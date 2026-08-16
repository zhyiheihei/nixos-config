# authentik-nix 学习笔记

## 1. 是什么

`authentik-nix` 是 [authentik](https://github.com/goauthentik/authentik)
的非官方 Nix flake，提供包、NixOS module 和 VM 集成测试，作为官方
docker-compose 部署的替代方案。MIT 协议，178 star，项目明确声明与
goauthentik 官方无隶属关系。

## 2. 用法

- flake 输入后 `imports = [ authentik-nix.nixosModules.default ]`，
  配置 `services.authentik.enable`；
- `settings` 是 freeform YAML，可覆盖上游默认配置（email、avatars、
  analytics 等）；
- `environmentFile` 把 secret 放在 store 之外（如
  `/run/secrets/authentik/authentik-env`），README 建议用 sops-nix 或
  agenix 管理；
- 默认创建本地 PostgreSQL；可选 `nginx.enable` + `enableACME`；
- 还提供 outpost 服务：`authentik-ldap` / `authentik-proxy` /
  `authentik-rac`，各自有独立 `environmentFile`。

## 3. 实现

- 用 flake-parts 组织 outputs，pin `authentik-src`
  （`version/2026.5.6`）和 client-ts generator；
- Python 环境用 uv2nix + pyproject-nix + pyproject-build-systems：
  `loadWorkspace` → `mkPyprojectOverlay` → `mkVirtualEnv`；
  README 里关于 poetry2nix 的提法已经过时；
- `lib.mkAuthentikScope` 用 `makeScope`/`newScope` 提供可覆盖的组件
  作用域：frontend、pythonEnv、gopkgs（server/outposts）、rust、
  manage、migrate、staticWorkdirDeps、docs；
- 还有 `terraform-provider-authentik` 包；
- module 里 `settings` 用 `pkgs.formats.yaml` freeform type，配置
  systemd services、tmpfiles、postgresql 和可选 nginx。

## 4. 测试与 CI

- `checks.vmtest`：NixOS VM 集成测试，启动 postgres + migrate +
  worker + server，用 OCR 确认前端渲染，模拟初始 admin 设置流程，
  并验证版本号、metrics 端口；
- `checks.override-scope`：验证组件 scope 可覆盖；
- `check.yml`：用 DeterminateSystems + Lix installer 跑
  `nix flake check`；
- 构建结果走 nix-community CI 和 Cachix 缓存。

## 5. 对我们仓库的启发

- 我们目前没有 authentik 需求，但以后若自建 IdP，这是比官方
  docker-compose 更符合我们 Nix 部署风格的选择；
- 值得借鉴：freeform YAML settings + `environmentFile` 分离 secret，
  以及用 VM 测试跑真实“初始设置”流程并用 OCR 验证 UI；
- uv2nix 构建 Python 环境的路线和我们对 Python 包的
  “nixpkgs 原生优先”判断一致。

## 6. 参考

- [authentik-nix](https://github.com/nix-community/authentik-nix)
- [authentik](https://github.com/goauthentik/authentik)
