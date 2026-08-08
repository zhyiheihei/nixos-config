# buildbot-nix 学习笔记

## 1. 是什么

`buildbot-nix` 是 NixOS module，把 [Buildbot](https://www.buildbot.net/) 变成
面向 Nix flakes 的 CI。维护者 `@Mic92` / `@MagicRB`，MIT 协议，2023 年创建，
当前 281 star / 43 fork。

核心特性：

- 用 `nix-eval-jobs` 并行求值 `.#checks`；
- GitHub / Gitea 集成：webhook、commit status、登录控制构建；
- 所有构建共享同一个 Nix store；构建产物创建 GC root 防止被回收；
- 除 Nix 沙箱外不运行任意代码；
- 实验性支持 hercules-ci effects，跑 impure 步骤（如部署）。

## 2. 架构

- `nixosModules/buildbot-master.nix`：master 配置（数据库、auth backend、
  GitHub/Gitea/OIDC、public/fullyPrivate 访问模式、postBuildSteps、
  Cachix 上传）；
- `nixosModules/buildbot-worker.nix`：worker 服务，用 `nix-eval-jobs`
  求值并执行构建，worker 数量默认等于 CPU 核数；
- Python 包 `buildbot_nix/`：
  - `nix_eval.py`：并行求值并收集每个 attr；
  - `build_trigger.py`：为每个 attr 动态触发一个 build；
  - `nix_build.py`：执行 `nix build` 并安全写 outputs；
  - `github_projects.py` / `gitea_projects.py`：仓库发现、webhook、
    commit status、登录；
  - `__init__.py` 的 `NixConfigurator` 把配置组装成 Buildbot master。

## 3. 工作流

1. PR 打开或默认分支 push 触发 webhook；
2. 拉取仓库，读取根目录可选的 `buildbot-nix.toml`（`lock_file`、
   `attribute`、`flake_dir`、effects 配置等）；
3. `nix-eval-jobs` 并行求值 `.#checks`，每个 attribute 成为一个构建；
4. 构建共享 Nix store；产物写 outputs 并建 GC root；
5. 向 PR / 默认分支报告状态；成功后可 push 到 Cachix；
6. effects 默认只在默认分支跑，配置从默认分支读取，避免 PR 作者
   给自己开权限（PR effects 有泄密风险，需显式开启）。

## 4. 认证与访问

- `public`（默认）：匿名只读，写操作要登录，支持 GitHub App / Gitea /
  通用 OIDC；
- `fullyPrivate`：用 `oauth2-proxy` 保护整个实例，支持组织和团队白名单；
- 角色：配置里写死的 admin 可 reload 项目列表，组织成员可重启构建；
- 每仓库可用 `buildbot-nix.toml` 覆盖 lock 文件、求值 attribute 等。

## 5. 工程与 CI

- worker module 断言 `nix-eval-jobs >= 2.26.0`，并为 worker 用户配置
  GC root 权限；
- 自带 NixOS VM 测试（master、worker、poller、gitea、scheduled-effects），
  本地开发用 `nix run .#buildbot-dev` 起 SQLite + 4 个本地 worker；
- 仓库自身 CI 用 herculesCI（dogfood 自己的效果系统），GitHub Actions
  只负责每周更新 flake 输入和自动合并依赖 PR；
- 与 lix overlay 不兼容（lix 覆盖的 `nix-eval-jobs` 缺功能）。

## 6. 对我们仓库的启发

- 我们目前的 Nix 构建靠 GitHub Actions + ml-builder 远程构建，包量不大，
  不需要自建 Buildbot；
- 它的 master/worker + remote builder 模式和 ml-builder 的远程构建
  思路相近；如果以后要脱离 GitHub 或做私有 Nix CI，buildbot-nix 是
  成熟选项；
- 值得借鉴：把 `.#checks` 作为唯一构建入口、共享 store、用 GC root
  保护构建产物。

## 7. 参考

- [buildbot-nix](https://github.com/nix-community/buildbot-nix)
- [buildbot.nix-community.org](https://buildbot.nix-community.org/)
- [nix-eval-jobs](https://github.com/nix-community/nix-eval-jobs)
