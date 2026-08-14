# 主机改名：cnvm -> volcengine

## 目标

- 把逻辑主机 `cnvm`（火山引擎 CN VPS）改名为 `volcengine`，系统 hostname、
  FQDN（`cnvm.zhyi.cc` -> `volcengine.zhyi.cc`）与全部 DNS 记录一并改名。
- 改名过程中运行中的服务不受影响：`index=119` 保持不变，所有地址
  （LTNET `198.18.0.119`、ZeroTier 静态 IP、wgmesh 接口、dn42 IPv4、
  wg-zhyi 端口段）均不变化。
- 旧名 `cnvm.zhyi.cc` 立即移除（不保留 CNAME 别名），仓库内消费者全部
  对应更新。

## 关键机制

- `hosts/<n>/` 目录名是唯一真源：flake 的 `nixosConfigurations.<n>` 键、
  `networking.hostName`、colmena 节点键、`LT.hosts` 键、ZeroTier 成员名、
  自动 DNS 记录（A/AAAA/SSHFP/PTR/NS 委托）、sops per-host 路径
  （`per-host/wg-priv/<hostname>.yaml`）、备份 `--host` 标签全部由目录名
  派生，**目录改名后自动跟随**。
- `host.nix` 的 `hostname` 字段只被两处消费：colmena `targetHost`
  （`colmena-deployment.nix`）与部署标签分类；改名时同步改成新 FQDN。
- `index` 与目录名解耦，保留不变即可保证所有地址不漂移。

## 改动清单（按仓库）

### nixos-secrets（commit d16efcf）

- `.sops.yaml`：age 锚点 `&cnvm` -> `&volcengine`（age 值不变，已加密
  yaml 无需重加密；历史先例 jpvm->hostdare、colocrossing->greencloud 同此）
- `per-host/wg-priv/cnvm.yaml` -> `volcengine.yaml`（git mv，加密文件纯改名）
- `wg-pubkey.nix`：公钥映射键名 `cnvm` -> `volcengine`（值不变）
- `homepage-dashboard-config.nix`：halo 监控 URL 改为主机名子域
- `README.md`：Attic 运维流程中的主机名 / `.#cnvm` flake 目标

### nixos-config（commit e604aa0c + c2c9884f）

- `hosts/cnvm/` -> `hosts/volcengine/`（git mv）
- `host.nix`：`hostname`、`tcpTransportDomain` 改 `volcengine.zhyi.cc`
- DNS：`dns/common/nameservers.nix`（NS 委托）、`host-recs.nix`
  （提供商别名 `LT.hosts.cnvm`）、`zhyi.xin.nix`（bitwarden/id/login CNAME
  与 apex A）、`zhyi.cc.nix`（`halo.volcengine` CNAME）
- `helpers/constants/public-sites.nix`、`prometheus/blackbox-exporter.nix`
  （`n != "volcengine"` 过滤）
- docs 全量同步（22 个文件，含 CNVM -> VOLCENGINE 的 mermaid 节点）
- `flake.lock`：secrets 输入固定到新 rev（`nix flake update secrets`，
  私有仓库需 `NIX_CONFIG="access-tokens = github.com=<token>"` 才能解析
  HEAD）

### 无需改动

- `zhyi-packages`（已确认 0 命中）

## 上线顺序（本次实际执行的顺序）

1. **secrets 先提交推送** -> 主仓库 `nix flake update secrets` 固定 rev。
2. **主仓库提交推送**，ml-builder 拉取。
3. **DNS push**：`nix run .#dnscontrol -- push`（gcore + bind zones）。
   - bind/DN42 zones 写本地 `zones/` 目录后，需再手动
     `rsync zones/ ci@rsync-ci.zhyi.cc:/ltnet-zones/` 同步到 coredns
     （GitHub Actions 的 rsync 步骤因 workflow 的 IFD 故障未跑）。
4. **先部署证书签发机 greencloud**（中心 ACME，gcore DNS-01）：它会按新
   配置签发 `lets-encrypt-volcengine.zhyi.cc` / `zerossl-*` 并同步到各机。
5. **再部署目标机**：`colmena apply --on volcengine`（此时 targetHost
   已是新 FQDN，需先确认新域名解析就绪）。
6. **部署消费者主机**：tencent（blackbox 过滤）、rock5c（homepage URL）。

## 踩坑记录（本次成功经验）

1. **`.gitignore` 的 `reference/` 规则顺带忽略了 `docs/reference/`**，
   导致 `rg docs/` 与批量替换都漏掉 `hosts-overview.md`。改名后复查必须
   `rg -i <旧名> --no-ignore --hidden -g '!.git'` 全库验证。
2. **gcore 刚改完区后，ACME 的 lego 添加 `_acme-challenge` TXT 会瞬时
   500**（`gcore: add txt record: 500: internal server error`），且
   `acme-order-renew-*.service` 在 auto-restart 等待。不要误判为结构问题
   （通配符 CNAME 不是障碍，可用 `lego ... -d <host>.zhyi.cc -d
   '*.<host>.zhyi.cc' run` 在 /tmp 目录实测对比）；稍后重试或
   `systemctl restart acme-order-renew-...` 即恢复。
3. **证书未到位时部署会卡在 nginx reload**：新 vhost 引用
   `/nix/sync-servers/acme/lets-encrypt-<hostname>.zhyi.cc-rsa/`，
   证书不存在则 `nginx -t` 失败、switch 进入半状态（重启会断网）。
   处理：等证书签发并 `systemctl start rsync-nix-sync-servers.service`
   同步后，重跑 `colmena apply` 即可完整切换。
4. **DNS 顺序**：colmena targetHost 是新 FQDN，必须 DNS push 后再部署；
   证书的 DNS-01 challenge 也需要新记录先在 gcore 生效。
5. **`nix flake check` 因仓库的 nixpkgs patching（IFD）在全局失败**是
   既有问题，验收用"目标主机逐一求值"：
   `nix eval .#nixosConfigurations.<host>.config.system.build.toplevel.drvPath`。

## 验证清单

- `rg -i cnvm` 全库 0 命中（`--no-ignore`）。
- 代表主机求值通过：volcengine / tencent / greencloud / rock5c。
- `nix build .#dnscontrol-config` 生成的 config.js 无旧名、有新名记录。
- 公网入口：login / id / bitwarden / attic `.zhyi.xin` 返回 200；
  `halo.volcengine.zhyi.cc` health 200（LTNET 网格内）。
- 目标机：hostname、`systemctl --failed` 为空、新证书四套落盘、
  wg mesh 全部在握手、LTNET 地址不变。

## 回滚

- `git revert` 两个仓库的改名提交 -> 重推 DNS -> 重新部署。
  `index=119` 不变，无地址漂移，回滚不涉及网络拓扑变更。

## 遗留 / 后续

- 本次核查发现 secrets `.sops.yaml` 存在历史改名残留（非本次引入）：
  `&sgvm` 锚点装着 greencloud 机器的实际 age key（锚点名未随
  colocrossing->greencloud 迁移更新），`&greencloud` 锚点值是已不存在的
  旧机器 key，`&logvm` 锚点是孤儿 key（无对应主机、无文档）。
  功能无碍（greencloud 靠 `&sgvm` 值解密），建议后续在 ml-builder 上
  对齐锚点名并清理陈旧/孤儿锚点。
