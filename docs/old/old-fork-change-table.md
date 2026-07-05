# 从原项目修改的提交表

本文根据当前 Git 历史整理，从原作者项目进入个人适配后的主要修改。

判断分界：

- `0ec99c65` 之前：基本是原作者项目历史。
- `0ec99c65` 起：开始出现个人机器、个人 secrets、个人文档等适配提交。
- `reference-project/`：当前用于对照的原作者项目快照。

## 1. 主仓库提交表

| 提交 | 日期 | 修改主题 | 主要改动 | 当前复刻状态 |
| --- | --- | --- | --- | --- |
| `0ec99c65` | 2026-07-02 | 引入个人设备雏形 | 新增根目录 `configuration.nix`、`hardware-configuration.nix`，新增 `hosts/ml-2700u/*`，修改 `flake.nix` 和 `.gitignore` | 部分保留。根目录两个配置文件是临时迁移痕迹；`ml-2700u` 是个人设备，不属于原版 |
| `7ff1c19a` | 2026-07-02 | secrets 仓库换成个人 GitHub | `flake.nix` 的 `secrets` 从原作者仓库改为你的 GitHub 仓库 | 必须保留。复刻时也不能使用原作者私有 secrets |
| `1ef5f70a` | 2026-07-02 | secrets 改为 SSH URL | `secrets.url` 改成 `git+ssh` 形式 | 必须保留。私有仓库需要 SSH 或其它认证方式 |
| `3126df26` | 2026-07-02 | 精简 `ml-2700u` 配置 | 大幅删除从安装配置拷来的内容，保留项目模块导入 | 保留个人 host 时可保留；严格原版没有 `ml-2700u` |
| `9fc70238` | 2026-07-02 | 临时修根分区 | 给 `ml-2700u` 增加普通根分区配置 | 偏离原版。作者体系应走 `/` tmpfs + `/nix/persistent` |
| `7a0a0d5f` | 2026-07-02 | 清理配置参数 | 删除不必要 `pkgs` 参数 | 中性，不影响复刻逻辑 |
| `c1d90988` | 2026-07-02 | 用户改成 `zhyi` | 把系统、Home Manager、客户端模块里的 `lantian` 改为 `zhyi` | 已被后续 `20daa07b` 基本撤回。复刻原版应使用 `lantian` |
| `a90bd2ad` | 2026-07-02 | OpenSSH override 调整 | 在个人 host 里用 `lib.mkOverride` 放宽 SSH | 偏离原版。原版 `ssh-harden.nix` 禁止密码登录，端口 `2222` |
| `b836bfa7` | 2026-07-02 | SOPS key 路径临时调整 | 给 `ml-2700u` 加 `sops.age.sshKeyPaths = [ "/etc/ssh/..." ]`，并改了一个包引用 | 偏离原版。原版 SOPS key 路径是 `/nix/persistent/etc/ssh/...` |
| `df8b6c00` | 2026-07-02 | 新增适配文档 | 新增 `docs/README.md`、`docs/adapt-own-device.md` | 文档可保留，不影响复刻运行 |
| `797a3b26` | 2026-07-02 | README 改成个人 fork 说明 | 根 README 从原作者说明改为你的仓库说明 | 运行无影响；字面上不是原版 |
| `4e9f8ae4` | 2026-07-03 | nixpkgs 改为 `26.05` | `flake.nix` 从原版 `nixos-unstable` 改到 `nixos-26.05` | 明显偏离原版。严格复刻应恢复原版 channel |
| `6a4507a2` | 2026-07-03 | 允许 insecure pnpm | `flake-modules/nixpkgs-options.nix` 加 `pnpm-10.29.2` | 个人构建绕过项。严格复刻需评估是否删除 |
| `dfe02bc3` | 2026-07-03 | KDE session 改为 `plasma` | 修改 `nixos/client-components/kde.nix` | 当前与原版不一致。原版 KDE 模块是空模块 |
| `960e77de` | 2026-07-03 | 自建构建缓存文档 | 新增 GitHub Actions self-hosted workflow、Docker builder、self-hosted builder 文档 | 文档/辅助工作流，可保留；不属于原版 |
| `d9c109f2` | 2026-07-03 | 完善 Docker 构建文档 | 强化 Windows Docker 强机器操作步骤 | 文档可保留 |
| `c7ab78c7` | 2026-07-03 | 接力构建日志与命令参考 | 新增 `docker-builder-command-reference.md` 和救援日志 | 文档可保留 |
| `305ac75f` | 2026-07-04 | 修 nginxfmt 参数 | 去掉 `--max-empty-lines 0`，更新相关构建文档 | 代码上偏离原版，但这是兼容新版工具的修复；需看原版是否也已更新 |
| `3087c5c0` | 2026-07-04 | 新增 `ml-2700u` 和 `ml-builder` | 新增两个个人 host，新增 Attic/S3/hosts/rollback/todo 文档，给 `ssh-harden.nix` 加中文注释 | 个人 host 和文档可保留；`ssh-harden.nix` 逻辑与原版一致，只是注释不同 |
| `c9087494` | 2026-07-04 | 新增 `ml-builder` 测试文档 | 新增强构建机测试步骤 | 文档可保留 |
| `421e5e0f` | 2026-07-04 | `ml-builder` 临时改 ext4 根分区 | 强制覆盖 `/` 为 ext4，绕开 impermanence | 已被后续撤回。复刻原版不应保留 |
| `d984f4a9` | 2026-07-04 | 临时关闭 preservation/userborn 原路径 | 关闭 preservation，把 userborn 改回 `/var/lib/nixos` | 已被后续撤回。复刻原版不应保留 |
| `908d8152` | 2026-07-04 | 提交 `.DS_Store` | 新增 macOS Finder 元数据 | 不应保留。建议从仓库移除并加入 `.gitignore` |
| `31db9bdc` | 2026-07-04 | 更新 lock | `flake.lock` 大幅变化 | 取决于 flake channel 决策。若回原版 channel，需要重新 lock |
| `20daa07b` | 2026-07-04 | 用户恢复 `lantian` | 把系统用户、Home Manager、客户端模块从 `zhyi` 改回 `lantian`，撤回 `ml-builder` 的临时 ext4/preservation 绕过 | 符合复刻方向 |

## 2. 当前仍然偏离原版的主项

| 项目 | 当前状态 | 原版状态 | 建议 |
| --- | --- | --- | --- |
| `flake.nix` channel | `nixos-26.05` | `nixos-unstable` + `nixos-25.05` | 若严格复刻，恢复原版 channel |
| `flake.nix` inputs | 移除了 `dms`、`niri-flake` 等 | 原版包含这些输入 | 若严格复刻，恢复输入 |
| `secrets.url` | 指向 `zhyiheihei/nixos-secrets` | 指向原作者私有仓库 | 必须保持个人替换 |
| `stylix` input | `github:nix-community/stylix` | `github:make-42/stylix/matugen` | 严格复刻应恢复原版 |
| `nixos/client-components/kde.nix` | 启用了 KDE/Plasma | 原版是空模块 `_: { }` | 若一比一原版，恢复空模块 |
| `hosts/ml-*` | 个人新增主机 | 原版没有 | 保留作为个人适配层 |
| `README.md` | 个人 fork 说明 | 原作者 README | 运行无影响；严格字面复刻则恢复 |
| `.DS_Store` | 已进入提交历史 | 原版没有 | 建议移除并加入 ignore |
| `docs/` | 大量个人适配文档 | 原版没有这些文档 | 可保留，不影响系统逻辑 |
| `.github/workflows/build-nixos-self-hosted.yml` | 新增自建构建工作流 | 原版没有 | 可保留为个人辅助 |

## 3. 当前已回到原版的关键项

| 文件 | 状态 |
| --- | --- |
| `nixos/minimal-components/users.nix` | 已与 `reference-project` 一致 |
| `nixos/minimal-components/home-manager.nix` | 已与 `reference-project` 一致 |
| `nixos/minimal-components/impermanence.nix` | 已与 `reference-project` 一致 |
| `nixos/client-components/impermanence.nix` | 已与 `reference-project` 一致 |
| `nixos/client-components/xorg.nix` | 已与 `reference-project` 一致 |
| `nixos/minimal-components/ssh-harden.nix` | 逻辑一致，主要是中文注释差异 |

## 4. local-secrets 仓库提交表

`local-secrets/` 是你替代原作者私有 `nixos-secrets` 的仓库，不在原项目内，但复刻时必须准备。

| 提交 | 修改主题 | 复刻意义 |
| --- | --- | --- |
| `cbeb665` | 初始化 secrets repo scaffold | 建立个人 secrets 仓库骨架 |
| `1b2998f` | 添加 lantian 通知邮箱 | 补齐原版常引用的 `glauthUsers.lantian.mail` |
| `7f5a8c1` | 更新 lantian 邮箱 | 改成你的邮箱 |
| `1f7ea1a` | 主用户改为 zhyi | 早期个人化，现应视为历史绕路 |
| `aac425e` | 添加 zhyi SSH 公钥 | 早期个人登录方式，现主线回到 `lantian` |
| `f23a448` | 配置 SOPS age recipient | 让 SOPS 能加密给目标机 |
| `a2d864a` | 添加 common SOPS 占位 | 补齐主项目 build/eval 需要的基础 secret 文件 |
| `746a3ae` | 准备用户和 builder SSH keys | 给登录和远程构建提供公钥入口 |
| `ef99b3b` | 写 secrets workflow 文档 | 记录个人 secrets 操作方式 |
| `b218450` | 添加个人 SSH client 配置 | 个人化内容，严格复刻需谨慎 |
| `4737290` | 使用 upstream-style SSH host metadata | 朝原版 SSH 管理方式靠拢 |
| `c1891e2` | 添加 ml_builder age key | 让 `ml-builder` 可以解密 secrets |
| `f3c4d67` | 移除旧 key，添加占位生成脚本 | 处理 `ml-2700u` 丢失旧 SOPS key 后的恢复 |
| `6105391` | 改进 placeholder 脚本 | 支持缺少本地 sops 时通过 nix shell 运行 |
| `41d20ef` | 更新加密 secrets、移除默认密码 | 当前远端 secrets 状态 |

当前 `local-secrets` 还有未提交修改：

- `README.md`
- `glauth-users.nix`
- `ssh/lantian.nix`

这些修改是为了把主线用户恢复为 `lantian`，应在确认后提交并推送。

## 5. 复刻建议顺序

1. 保持主项目核心模块与原版一致：
   - `users.nix`
   - `home-manager.nix`
   - `impermanence.nix`
   - `ssh-harden.nix`

2. 只在这些位置做个人化：
   - `hosts/ml-*`
   - `local-secrets`
   - 文档
   - 缓存/构建辅助工作流

3. 对会影响全局行为的修改要单独决策：
   - `flake.nix` channel
   - `nixos/client-components/kde.nix`
   - overlays/patches
   - `flake.lock`

4. 当前最值得先清理的偏离：
   - [ ] 删除 `.DS_Store` 并加入 `.gitignore`
   - [ ] 决定是否恢复原版 `flake.nix`
   - [ ] 决定是否恢复原版 `kde.nix`
   - [ ] 提交并推送 `local-secrets` 中 `lantian` 相关修改
   - [ ] 在 `ml-builder` 上验证 `/nix/persistent` 原版路径
