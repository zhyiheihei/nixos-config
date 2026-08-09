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
- 插件后端当前无法在 MoviePilot v2.15.5 加载：`OidcAuth` 0.3.x 引用了
  `app.core.auth_bridge`，该模块在 v2.15.5 与上游 master 均不存在，
  导致 `/api/v1/plugin/OidcAuth/authorize`、`callback` 返回 404。
- 结论：Pocket ID 登录按钮可显示，但实际登录/回调未生效；需等上游
  MoviePilot 提供 `auth_bridge` 核心模块，或换用不依赖该模块的登录方案。

## 注意事项

- Dex 静态客户端的 `redirectURIs` 必须与应用的 OIDC 回调完全一致。
- 不要把 `client_secret` 写入主仓库；只放在 secrets 的 sops 加密文件。
- 新增客户端时同步更新 `common/dex.yaml`、`dex.nix`、`flake.lock`，
  缺一不可，否则部署会失败或登录回调不匹配。
- 不再使用的 Dex secret 引用要从 `dex.nix` 一并删除，否则
  `sops-install-secrets` 会报“secret not found”。
