# dns.nix 学习笔记

## 1. 是什么

`dns.nix` 是“用 Nix 定义 DNS zone”的 DSL，作者 Kirill Elagin，
双许可证 MPL-2.0 / MIT（MIT 用于和 nixpkgs 直接兼容），当前版本
1.1.2。它把 zone 定义写成 NixOS module，再用 `lib.evalModules`
强类型求值并序列化成 zone 文件。

## 2. 核心 API

- `dns.lib.evalZone name zone`：用内置的 `zones` option 求值一个
  zone，得到规范化结构；
- `dns.lib.toString name zone`：把 zone 转成 zone 文件文本；
- `dns.lib.types`：DNS 相关模块类型（`zone`、`record`、`domain-name`
  等）；
- `dns.util.writeZone name zone`：求值后直接写 `*.zone` 文件；
- `mkIPv4ReverseRecord` / `mkIPv6ReverseRecord`：生成 PTR 反向记录。

支持的记录类型很全：A、AAAA、CAA、CNAME、DKIM、DMARC、DNAME、DNSKEY、
DS、HTTPS、MX、NS、OPENPGPKEY、PTR、SOA、SRV、SSHFP、SVCB、TLSA、TXT。

## 3. 组合子（combinators）

- 简单记录：`a`、`aaaa`、`cname`、`ns`、`txt`；
- 修饰符：`ttl`；
- 模板：`host`（同时给 A/AAAA）、`delegateTo`（NS 委托）、
  `mx.google`、`letsEncrypt`（CAA）、`spf`（soft/strict/google）、
  `dmarc.postmarkapp`。

## 4. 实现要点

- 强类型来自 NixOS module system：每种记录一个
  `dns/types/records/<TYPE>.nix`，zone 还支持模块合并，多个文件可以
  叠加到同一 zone；
- `evalZone` 用一个“假模块”求值：定义 `zones` option，再把目标 zone
  放进去，复用 module system 的检查；
- `useOrigin` 控制序列化用 FQDN 还是 `$ORIGIN` + `@`；
- `writeCharacterString` 按 RFC 1035 把超过 255 字节的 TXT 拆成多段；
- `domain-name` 类型限制最长 255 字符；
- flake 的 checks 是 `eval-lib`（`deepSeq` 求值库）和 `reuse` lint，
  仓库本身没有 GitHub Actions workflow。

## 5. 对我们仓库的启发

- 我们已用 DNSControl 管理 `dns/domains/*.nix`，目标 provider 是
  DNS 服务商，不需要切换到 zone 文件 DSL；
- 如果以后改走自建权威 DNS（NSD/BIND），dns.nix 是比手写 zone
  文件更安全的替代；
- 它“用 module system 给 DNS 记录做类型检查 + 记录类型独立文件”的
  结构值得参考，可以用于改进我们 DNSControl 配置的校验。

## 6. 参考

- [dns.nix](https://github.com/nix-community/dns.nix)
- [DNSControl](https://github.com/StackExchange/dnscontrol)
