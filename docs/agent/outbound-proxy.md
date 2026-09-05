# 集群出站代理（outbound proxy）

集群所有需要出站代理的服务（systemd unit environment、`environment.variables`、
构建链等）统一引用 [`helpers/proxy.nix`](../../helpers/proxy.nix) 的三个常量，
**禁止在 host/模块内内联拼 `socks5://`**。

## 常量

| 常量 | 值 | 说明 |
| --- | --- | --- |
| `LT.outboundProxy` | `socks5://<router interconnect IPv4>:<V2Ray SocksClient>` | 出站 SOCKS5 入口（router V2Ray） |
| `LT.proxyBypass` | `localhost,127.0.0.1,::1,192.168.0.0/16,198.18.0.0/15,.zhyi.xin` | 回环 + home LAN + LTNET（实际使用 /16）+ 集群域名 |
| `LT.proxyEnvironment` | 大小写成对的 `HTTP_PROXY`/`HTTPS_PROXY`/`NO_PROXY` 等 | 直接喂给 `environment.variables` 或 unit `environment` |

个别服务要豁免更多域名时，以 `"${LT.proxyBypass},<域名>"` 覆盖 `NO_PROXY`/
`no_proxy` 追加，不要另起一份列表（work-norms §10）。已有豁免：

- **m-team PT 域名**（`.m-team.cc` 等）：rock5c、dragon-q8b（NCPS）、opi5p。
- **docker.m.daocloud.io**（镜像加速）：frigate/redroid 镜像拉取直连。
- **GOPROXY**：ml-builder、opi5p 的 `environment.variables` 额外叠加
  `GOPROXY = "https://goproxy.cn,direct"`。
- **nix FOD 拉取直连清单**（ml-builder）：对构建日志中全部 65 个拉取域名
  逐一实测（`curl --noproxy`），50 个直连稳定（kde/gitlab.debian/fedora/
  arch/gentoo 各镜像、hackage、crates.io、pythonhosted、kernel.org 等），
  经出口代理反而被上游 403（invent.kde.org、KDE GitLab 反代出口 IP）、
  502 或降到 KB/s；清单固化在 `hosts/ml-builder/configuration.nix` 的
  `fetchDirectHosts`。github、`*.googlesource.com`、discord、
  archive.torproject.org、download.gnome.org、patch-diff.githubusercontent.com
  等直连不可达，仍走代理。更新方法：重跑构建 → 从日志提取
  `trying https://` 域名 → 逐一探测直连 → 增删清单。

## 实现注意：helpers/default.nix 不走 callPackage

`proxy` 用普通 `import ./proxy.nix { inherit hosts portStr; }` 接入而非
`call`：`callPackageWith` 会构造 `pkgs // helpers` 参数集，而 `pkgs` 在 NixOS
上下文绑定每主机 `_module.args.pkgs`，主机配置引用 proxy 时会形成无限递归。
普通 import + 显式传参只强制求值用到的 attr。

## 已有接入点

| 位置 | 说明 |
| --- | --- |
| 各 host `environment.variables` | 交互 shell 的代理（proxyBypass/proxyEnvironment 由 host 层维护） |
| ml-builder `nix-daemon` | FOD fetch 走 daemon、flake lock 拉取走发起客户端，两侧共用同一代理；内网服务由 bypass 直连 |
| dragon-q8b NCPS | 上游缓存（cache.nixos.org / attic）经 rock5c mihomo mixed 口出站（`http://rock5c:7892`；2026-09-05 起，替换间歇断流的 router SOCKS5） |
| ml-laptop `hydra-evaluator` | evaluator（及其 fork 的 nix fetch 子进程）直连 GitHub 拉 flake inputs 实测长期卡死（2026-09-04），给 evaluator unit 注入代理；bypass 已含 opi5p ncps substituter 与 LTNET，均直连 |
| frigate / redroid 容器 | 镜像拉取走代理 + 镜像加速域名直连 |

## 禁令：代理绝不喂给 nix-daemon（opi5p 案例）

曾用 `systemd.services.nix-daemon.environment = config.environment.variables`
把代理全量灌进 opi5p 的 daemon。daemon 的出站 HTTP 经 router V2Ray 阻塞时
连接不退，客户端超时重连 → sshd/nix-daemon 连环孵化 → OOM 死循环
（2TB NVMe 时代与 SD 重装时代均复现；dragon/ml-builder 的 daemon 无代理故
永不触发）。**代理只作用于交互 shell 与显式声明代理的服务**，nix-daemon 的
substituter 访问依靠 `connect-timeout`（15s）与直连。
