# 新增用户规范与流程

> 建立于 2026-10-08。本文是「往账号体系加人」的唯一规范；身份链静态架构见
> [身份认证架构](identity-auth-architecture.md)，OIDC 应用侧见
> [OIDC 应用接入规范](oidc-app-integration.md)。

## 一句话

账号体系只有一个用户来源：secrets 仓库的 `glauth-users.nix`（凭据）+ 本仓
`nixos/optional-apps/glauth.nix`（目录条目）。改这两处并部署，整条身份链自动
跟随，**不要在任何下游组件单独建号**。

```
glauth-users.nix (bcrypt/mail) ─┐
                                ├─> glauth LDAP (dc=zhyi,dc=xin)
glauth.nix ([[users]] 条目) ────┘        │
                                          ├─> Pocket ID（每小时同步，Passkey 登录）
                                          ├─> Dex（login.zhyi.xin → Pocket ID）
                                          ├─> nginx BasicAuth（htpasswd）
                                          └─> Radicale / Quassel / Matrix Synapse（直连）
```

## 命名与编号规范

| 项 | 规范 | 现状 |
| --- | --- | --- |
| `name` / `uid` | 全小写字母或数字，不用点、横线、下划线 | zhyi、maoda、xiaoliu、laozhou、serviceuser |
| `uidnumber` | 1000 起顺序分配，一旦分配不再改动（Pocket ID 用 `uid` 做唯一标识） | 1000 zhyi、1001 maoda、1002 xiaoliu、1003 laozhou（下一个 1004） |
| `primarygroup` | 普通用户 101（`users`）；管理员 100（`admin`）；服务账号 60000（`svcaccts`） | 只有 zhyi 在 100 |
| `givenname` / `sn` | 由用户名拆两段，首字母大写 | xiaoliu → Xiao / Liu |
| `displayName` | `givenname sn` | Xiao Liu |
| `mail` | 必填，且要真实可达 | Pocket ID 的一次性登录码会发到这里 |
| `passBcrypt` | bcrypt，成本 05，`$2b$` 前缀 | 与既有哈希格式一致 |

**不要把人加进 `admin` 组**（gid 100）。Pocket ID 用 `LDAP_ADMIN_GROUP_NAME=admin`
判定管理员，进组等于给身份提供方管理员权限。

## 密码规范

明文密码只存在于用户和 secrets 的 `common/default-pw.yaml`（仅 zhyi 那个统一
口令）；`glauth-users.nix` 只存 bcrypt。生成：

```bash
mkpasswd -m bcrypt -R 5 '<明文>'
# $2b$05$...
```

工具若输出 `$2y$` 前缀，手动改成 `$2b$`（glauth 走 Go bcrypt，只认 2a/2b）。
`glauth.nix` 会用 `hexdump` 把哈希转成十六进制再写进配置文件，这是既有约定，
照抄即可。

## 操作流程

以新增用户 `foo` 为例。

### 1. 生成哈希

```bash
mkpasswd -m bcrypt -R 5 '<明文>'
```

### 2. 改 secrets（`~/Documents/nixos/nixos-secrets`）

`glauth-users.nix` 追加：

```nix
  foo = {
    # Interactive user.
    passBcrypt = "$2b$05$...";
    mail = "someone@example.com";
  };
```

提交并 push（提交信息写清为什么）：

```bash
git add glauth-users.nix && git commit -m "feat(glauth): 新增 foo 用户" && git push origin main
```

### 3. 改本仓 `nixos/optional-apps/glauth.nix`

在 `serviceuser` 之前追加条目：

```nix
    [[users]]
      name = "foo"
      givenname = "Fo"
      sn = "Oo"
      mail = "${glauthUsers.foo.mail}"
      uidnumber = 1004
      primarygroup = 101
      passbcrypt = "${hexdump glauthUsers.foo.passBcrypt}"
      [[users.customattributes]]
        displayName = ["Fo Oo"]
```

bump secrets 输入并提交：

```bash
https_proxy=socks5h://127.0.0.1:1080 nix flake update secrets
git add nixos/optional-apps/glauth.nix flake.lock && git commit -m "feat(glauth): 新增 foo 用户"
```

### 4. 部署两个 glauth 实例

`volcengine` 和 `rock5c` 是**两个独立实例**，数据不同步，必须都部署：

```bash
nix run .#colmena -- build --on volcengine,rock5c
make _push-host HOST=volcengine
make _push-host HOST=rock5c
```

两台都被 Makefile 判为 CN 主机，所以走「控制机并行推闭包 + switch」这条登记过的
偏移通道（`_push-host`），不是 `colmena apply`。

### 5. 验证

普通用户没有 LDAP search 权限，验证要用 `serviceuser` 身份查、用新用户身份
bind。用 `serviceuser` 的 bind 密码（secrets `common/glauth.yaml:glauth-bindpw`）
写出一个 0600 的临时文件，别放进命令行参数：

```bash
nix shell nixpkgs#openldap -c ldapsearch -x -H ldap://198.19.0.38:389 \
  -D "cn=serviceuser,dc=zhyi,dc=xin" -y /tmp/.gbpw \
  -b "dc=zhyi,dc=xin" "(&(objectClass=posixAccount)(!(ou=svcaccts)))" uid mail
```

`rock5c` 的 glauth 走 `198.19.0.38`；`volcengine` 的要开 SSH 隧道到它的 netns
地址（`198.18.119.38:389`，随主机 index 变化）。

再用新用户 bind 一次，判据是**错误密码返回 49、正确密码不返回 49**：

```bash
# 正确密码：bind 通过，search 因无权限返回 50 Insufficient access
# 错误密码：ldap_bind: Invalid credentials (49)
```

`ldapwhoami` 会报 `Protocol Error`——glauth 不支持 Who Am I 扩展操作，改用
`ldapsearch` 看返回码。

注意 `-y` 密码文件**不能带末尾换行**（`awk`/`grep` 重定向会多出 `\n`，导致密码
多个字节 bind 报 49）；生成时用 `printf '%s' "$var" > file`，不要用 `echo`。

### 6. Pocket ID 同步

Pocket ID 启动后几秒同步一次，之后每小时（本机是 `:11`）同步一次，管理界面
「Sync now」或 `POST /api/application-configuration/sync-ldap` 可立即触发。
`LDAP_SOFT_DELETE_USERS=true`，所以从 LDAP 消失的用户是被**禁用**而不是删除。
要立刻验证而不等整点，重启 `pocket-id` 即会立即跑一次同步。

确认：

```bash
sudo -u postgres psql pocket-id -Atc "select username, email, is_admin from users order by username;"
```

### 7. 通知用户首次登录

用户在 `https://id.zhyi.xin` 用 LDAP 密码登录一次并注册 passkey，之后所有接入
OIDC 的应用都免密。应用侧：已开启自动建号的应用（Memos 等）首次 SSO 登录自动
建用户；自带账号体系的应用（Immich / Jellyfin / qBittorrent / PVE 等）仍需在该
应用内单独建号，见身份认证架构里的「手动改密」表。

## 常见坑

- **邮箱重复**：Pocket ID 的 `users.email` 有唯一约束（`users_email_key`），两个用户
  写同一个邮箱会让整个 LDAP 同步事务回滚——不只是那个用户，**所有人一起同步失败**，
  日志里只会看到 `current transaction is aborted`，真正的原因要去 PostgreSQL 日志里找
  `duplicate key value violates unique constraint "users_email_key"`。同一个人用多个
  账号时，用子地址区分（`molishanguang+xiaoliu@outlook.com`，邮件仍进同一个收件箱），
  这也是 `xiaoliu` 目前的写法。
- **只部署一台**：两台 glauth 独立，漏一台会出现「Pocket ID 里有人但某台机器上
  的服务认不出来」。
- **忘了 bump secrets**：`glauth.nix` 引用的是 `inputs.secrets`，不
  `nix flake update secrets` 会拿到旧哈希。
- **`uidnumber` 复用**：Pocket ID 用 LDAP 的 `uid` 作为唯一标识，号码改了会造成
  旧用户与新用户串号；删人只删条目，号码不再启用。
- **把普通用户放进 admin 组**：等于授予身份提供方管理员。
- **改密码**：这是另一套流程（要同时改 `default-pw.yaml` 和 bcrypt），见身份认证
  架构的「改密操作步骤」。

## 相关文档

- [身份认证架构](identity-auth-architecture.md)：身份链静态架构、凭据清单、改密流程
- [OIDC 应用接入规范](oidc-app-integration.md)：新增 OIDC 应用
- [全主机服务归属与链路](fleet-service-chain.md)：运行态账本
