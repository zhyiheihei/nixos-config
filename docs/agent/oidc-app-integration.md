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
       "https://moviepilot.rock5c.zhyi.xin/api/v1/plugin/OidcAuth/callback"
     ];
   }
   ```

2. 在同一个文件的 sops secret 列表加入 `"moviepilot"`。
3. 在 secrets 仓库 `common/dex.yaml` 增加
   `dex-moviepilot-secret`（64 位随机 hex），用 `sops` 编辑并提交。
4. 更新主仓库 `flake.lock` 的 secrets 提交并部署 `volcengine`。
5. 在应用侧配置 OIDC：

   - issuer：`https://login.zhyi.xin`
   - client_id：与 Dex `id` 一致
   - client_secret：`common/dex.yaml` 对应密钥
   - scopes：`openid profile email`
   - username_claim：`preferred_username`
   - email_claim：`email`

## Home Assistant 当前配置（2026-09-04）

- 接入方式：hass-oidc-auth 插件（nixpkgs 现成包
  `home-assistant-custom-components.auth_oidc`，勿自打包分叉），经 Dex。
- Dex client `home-assistant` 是**公共 client（无 secret）**：安全性靠
  redirect URI 白名单 + PKCE（hass-oidc-auth 官方推荐方式）。
- 回调：`https://ha.zhyi.xin/auth/oidc/callback` 与
  `https://ha.opi5p.zhyi.xin/auth/oidc/callback`。

## MoviePilot 当前配置

- 插件：`OidcAuth`
- 登录按钮显示：Pocket ID
- issuer：`https://login.zhyi.xin`
- client_id：`moviepilot`
- redirect_uri：
  `https://moviepilot.rock5c.zhyi.xin/api/v1/plugin/OidcAuth/callback`
- `allow_auto_bind_by_username=true`，现有 `zhyi` 账号自动绑定。

## Memos 当前配置

- 接入方式：Memos 原生 OAuth2（OIDC Discovery 由 Dex 提供）。
- Dex client：`id=memos`，回调
  `https://memos.opi5p.zhyi.xin/auth/callback`，与 Memos 登录页的
  `/auth/callback` 完全一致。
- OAuth2 端点：`https://login.zhyi.xin/auth`、
  `https://login.zhyi.xin/token`、`https://login.zhyi.xin/userinfo`。
- field mapping：`identifier=preferred_username`、`email=email`，
  identifier filter 为 `^zhyi$`。
- Memos 首次 SSO 登录会创建新用户；既有 `zhyi` 需在
  Settings → Linked Identities 绑定一次，之后才能直接免密登录。
- 完整存储/通知/AI 配置见 [`docs/services/memos.md`](../human/services/memos.md)。

## 运行状态（2026-08-09）

- Dex 静态客户端与 secrets 已部署，插件配置与绑定状态页面正常。
- 已恢复并锁定：`OidcAuth 0.3.2`（`jxxghp/MoviePilot-Plugins` 官方仓库版本，
  兼容 MP 2.15.5，走 `app.core.auth.create_plugin_auth_ticket` 票据桥接）。
- MP 端官方机制：插件必须保留在 `UserInstalledPlugins`（否则 MP 只选择性加载
  已安装列表，插件根本不会加载）；同时把 `PLUGIN_MARKET` 固定为
  `https://github.com/jxxghp/MoviePilot-Plugins/`，防止启动时市场把插件自动
  升级成 `ui-beam-9` 的 0.3.5（该版本引用 MP 不存在的
  `app.core.auth_bridge`，后端会 404）。
- 实测链路：`/authorize` 307 → `login.zhyi.xin/auth` →
  `/auth/ldap`（Dex 单 connector 的标准中间跳转，connector id 因历史兼容保留
  为 `ldap`）→ `id.zhyi.xin/authorize` → `id.zhyi.xin/interaction`
  （Pocket ID 登录页）；`/callback` 200；
  `/api/v1/auth/providers` 正常暴露 Pocket ID；`/auth/exchange` 票据兑换端点存在。
- 绑定状态：`zhyi` 已绑定，sub/email 与 Pocket ID 一致；
  Dex 日志确认 `preferred_username=zhyi`、`email=molishanguang@outlook.com`。

## MoviePilot v3 迁移与 OIDC 现状（2026-08-27）

- **基线：rock5c 已锁定 moviepilot-v3**（`media-apps.nix` 的 mkForce，主模块
  同步对齐）。当日曾短暂尝试回退 v2，最终决定保持 v3、等官方支持。
- 域名统一回补：MP 内 `plugin.OidcAuth` 的 `redirect_uri` 从旧域
  `.zhyi.cc` 改为 `.zhyi.xin`（2026-08-20 单一域决策的残留），其余字段
  （issuer / client_id / secret / claims）核对无误。
- **OidcAuth 无官方 v3 适配**：逐一核对上游三套索引
  （package.json 79 条、package.v2.json 64 条、package.v3.json 22 条），
  仅 package.v2.json 含 `OIDC 认证 0.3.2`。v3 市场适配器声明「V3 临时默认兼容 V2」，
  因此插件可加载，但回调最后一环会因 v2 式数据库调用崩溃：
  `'NoneType' object has no attribute 'execute'`（`User.get(db=None, …)`）。
- **过渡期登录方式**：OIDC 登录暂不可用；MP 本地账号（zhyi）密码登录不受影响。
- 曾做本地补丁（`plugins-store/oidcauth/__init__.py` 三处改用 v3
  `UserOper`，备份 `__init__.py.bak-v032`），编译/导入/热重载均通过，
  但按用户决定等官方支持，不作为长期方案；补丁文件与快照
  `user.db.pre-v2-rollback` 留在数据卷备查，升级 v3 后如需可复用。
- 升级触发条件：`package.v3.json` 出现 oidcauth 条目（或本地补丁验证通过
  且用户重新启用）。届时直接使用现有配置即可，redirect_uri 已是新域。

## 官方用法对照

### MoviePilot 侧（OidcAuth 插件）

- 安装来源：`https://github.com/jxxghp/MoviePilot-Plugins`，版本 0.3.2；
  不要使用 `ui-beam-9/MoviePilot-Plugins` 的 0.3.5（依赖不存在的
  `app.core.auth_bridge`）。
- 配置字段（与当前值一致）：
  `issuer=https://login.zhyi.xin`、`client_id=moviepilot`、
  `scopes=openid profile email`、`username_claim=preferred_username`、
  `email_claim=email`、`allow_auto_bind_by_username=true`。
- 回调：`https://moviepilot.rock5c.zhyi.xin/api/v1/plugin/OidcAuth/callback`，
  与 Dex staticClient 的 `redirectURIs` 完全一致。
- 登录完成后由前端调用 `POST /api/v1/auth/exchange` 兑换一次性票据成 Token。

### Dex 侧（login.zhyi.xin）

- staticClient：`id=moviepilot`，secret 存 sops（`dex-moviepilot-secret`），
  `redirectURIs` 必须精确匹配插件回调。
- OIDC connector（Pocket ID）：`issuer=https://id.zhyi.xin`、
  `clientID=dex`、`redirectURI=https://login.zhyi.xin/callback`、
  `scopes=[email, profile, groups, offline_access]`、`getUserInfo=true`，
  声明经 Dex 映射为 `preferred_username` / `email`。

### Pocket ID 侧（id.zhyi.xin）

- 作为 Dex 的上游 OIDC Provider；Dex 以客户端 `dex` 注册，
  回调 `https://login.zhyi.xin/callback`。
- 登录为 passkey 免密；Dex 侧已有 `login successful` 记录，
  说明 connector 链路正常。

## 维护与故障恢复

系统设置必须通过官方 API 存“裸值”（数组/字符串），不能包成
`{"value": ...}`，否则 `UserInstalledPlugins` 会被存成字典导致插件不加载。

```bash
# 固定插件市场到官方 jxxghp 仓库（防止自动升级坏版本）
curl -X POST http://127.0.0.1:13890/api/v1/system/setting/PLUGIN_MARKET \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data '"https://github.com/jxxghp/MoviePilot-Plugins/"'

# 确保 OidcAuth 在已安装列表（裸数组）
curl -X POST http://127.0.0.1:13890/api/v1/system/setting/UserInstalledPlugins \
  -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  --data '["BrushFlow",...,"OidcAuth"]'

# 从官方仓库强制重装
curl "http://127.0.0.1:13890/api/v1/plugin/install/OidcAuth?repo_url=https%3A%2F%2Fgithub.com%2Fjxxghp%2FMoviePilot-Plugins&force=true" \
  -H "Authorization: Bearer $TOKEN"
```

## 注意事项

- Dex 静态客户端的 `redirectURIs` 必须与应用的 OIDC 回调完全一致。
- 不要把 `client_secret` 写入主仓库；只放在 secrets 的 sops 加密文件。
- 新增客户端时同步更新 `common/dex.yaml`、`dex.nix`、`flake.lock`，
  缺一不可，否则部署会失败或登录回调不匹配。
- 不再使用的 Dex secret 引用要从 `dex.nix` 一并删除，否则
  `sops-install-secrets` 会报“secret not found”。
- 不要从 `UserInstalledPlugins` 移除 `OidcAuth`：MP 只加载已安装列表里的
  插件，移除会导致登录入口消失。
