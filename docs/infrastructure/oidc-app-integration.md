# OIDC 应用接入规范（Pocket ID / Dex）

本文定义家庭/公网应用统一走 `login.zhyi.xin`（Dex）登录，
Dex 后端使用 Pocket ID（`id.zhyi.xin`）作为身份连接器。

## 接入步骤

1. 在 `nixos/optional-apps/dex.nix` 的 `staticClients` 增加客户端：

   ```nix
   {
     id = "moviepilot";
     name = "MoviePilot";
     secret = {
       _secret = config.sops.secrets.dex-moviepilot-secret.path;
     };
     redirectURIs = [
       "https://moviepilot.rock5c.zhyi.cc/api/v1/plugin/OidcAuth/callback"
     ];
   }
   ```

2. 在同一个文件的 sops secret 列表加入 `"moviepilot"`。
3. 在 secrets 仓库 `common/dex.yaml` 增加
   `dex-moviepilot-secret`（64 位随机 hex），用 `sops` 编辑并提交。
4. 更新主仓库 `flake.lock` 的 secrets 提交并部署 `cnvm`。
5. 在应用侧配置 OIDC：

   - issuer：`https://login.zhyi.xin`
   - client_id：与 Dex `id` 一致
   - client_secret：`common/dex.yaml` 对应密钥
   - scopes：`openid profile email`
   - username_claim：`preferred_username`
   - email_claim：`email`

## MoviePilot 当前配置

- 插件：`OidcAuth`
- 登录按钮显示：Pocket ID
- issuer：`https://login.zhyi.xin`
- client_id：`moviepilot`
- redirect_uri：
  `https://moviepilot.rock5c.zhyi.cc/api/v1/plugin/OidcAuth/callback`
- `allow_auto_bind_by_username=true`，现有 `zhyi` 账号自动绑定。

## 运行状态（2026-08-09）

- Dex 静态客户端与 secrets 已部署，插件配置与绑定状态页面正常。
- 已恢复：使用镜像内置 `OidcAuth 0.3.2`（`jxxghp/MoviePilot-Plugins` 版本，
  兼容 MP 2.15.5，通过 `app.core.auth.create_plugin_auth_ticket` 桥接）。
  已验证 `/authorize` 307 跳转 `login.zhyi.xin`、`/callback` 200、`status` 200。
- 易踩坑：插件市场 `ui-beam-9/MoviePilot-Plugins` 的 `OidcAuth 0.3.5` 会覆盖
  内置版本，且引用 MP 中不存在的 `app.core.auth_bridge`，导致后端 404。
  已把 `OidcAuth` 从 `UserInstalledPlugins` 移除，防止容器重启后市场自动
  安装/升级到坏版本。
- 若再次失效：用官方接口从 jxxghp 仓库强制重装并确认
  `UserInstalledPlugins` 不含 `OidcAuth`：
  `GET /api/v1/plugin/install/OidcAuth?repo_url=https%3A%2F%2Fgithub.com%2Fjxxghp%2FMoviePilot-Plugins&force=true`

## 注意事项

- Dex 静态客户端的 `redirectURIs` 必须与应用的 OIDC 回调完全一致。
- 不要把 `client_secret` 写入主仓库；只放在 secrets 的 sops 加密文件。
- 新增客户端时同步更新 `common/dex.yaml`、`dex.nix`、`flake.lock`，
  缺一不可，否则部署会失败或登录回调不匹配。
- 不再使用的 Dex secret 引用要从 `dex.nix` 一并删除，否则
  `sops-install-secrets` 会报“secret not found”。
