# sigtool 学习笔记

## 1. 是什么

`sigtool` 是 Nixpkgs Darwin bootstrap 关键的小工具：处理 Mach-O
文件里内嵌的 ad-hoc 代码签名（superblob / CodeDirectory），同时提供
一个可替代上游 `codesign` 的接口。35 star，MIT，C++11，
[release.nix](https://github.com/nix-community/sigtool/blob/main/release.nix)
明确写着它被用于 bootstrap tools 和 stdenv 构建。

当前支持 thin 和 universal 的 64 位 Mach-O 内嵌 ad-hoc 签名。

## 2. sigtool 子命令

```text
sigtool -f <mach-o> [OPTIONS] SUBCOMMAND

check-requires-signature   判断这个 Mach-O 是否必须签名
size                       计算签名 blob 大小
generate                   生成签名并输出到 stdout
inject                     生成并注入内嵌签名
show-arch                  显示架构
```

## 3. 签名结构

`signMachO` 构造一个 `SuperBlob`，包含：

1. **CodeDirectory**：页大小/哈希类型（SHA256）、
   `codeLimit`（LC_CODE_SIGNATURE 的 dataOff，即签名前缀范围）、
   逐 4096 字节页的代码 hash、requirements 的 specialHash、
   可执行文件标记 `CS_EXECSEG_MAIN_BINARY`、`__TEXT` 段的
   execSegBase/Limit；
2. **Requirements**：0 项的空列表；
3. 可选 **Entitlements** plist（及 `--generate-entitlement-der` 的
   DER 编码版本）；
4. **空 Signature slot**（ad-hoc 没有 CMS 签名）。

`inject` 把生成的 blob 写进已有的 `LC_CODE_SIGNATURE` 预留空间；
空间不够就报错。

## 4. codesign 兼容层

`codesign` 子命令面向构建工具：

- 支持 `-s`（identity，实际只是要求存在）、`-i`、`-f`、
  `--entitlements`、`--generate-entitlement-der`；
- `--timestamp=none` 作为 no-op 接受，真实 TSA 时间戳不支持
  （ad-hoc 签名没有可加时间戳的 CMS）；
- 流程：用 `posix_spawnp` 调 `codesign_allocate`（可用
  `CODESIGN_ALLOCATE` 环境变量指定）扩大签名空间，然后 inject，
  最后 rename 覆盖原文件；identifier 缺省取文件名 basename；
- 没有 `-f` 时遇到已签名文件会拒绝，避免破坏既有签名。

## 5. 构建与发布

- 依赖 OpenSSL + libplist（plist 解析）；CLI11 vendored；
- `Makefile` 供 bootstrap 用，`CMakeLists.txt` 还能编
  `libsigtool` 共享库并安装头文件；
- `release.nix`：x86_64/aarch64-darwin 原生和交叉、linux 原生和
  交叉，全平台可用于 bootstrap；
- `test/test.sh` 用 `construct` 库解析签名验证；
- 无 GitHub Actions，验证靠 nixpkgs bootstrap 构建链。

## 6. 对我们仓库的启发

- 我们是 Linux-only，不引入；
- 它是“bootstrap 关键工具独立成仓库、由 Nixpkgs 消费”的典型：
  小、无依赖偏好、`release.nix` 直接服务跨平台 bootstrap；
- `codesign_allocate + 临时文件 + 原子 rename` 的二进制原地修改
  模式，适合任何需要给二进制扩容后回写的工具。

## 7. 参考

- [sigtool](https://github.com/nix-community/sigtool)
- Nixpkgs 内的 [sigtool 包](https://github.com/NixOS/nixpkgs/tree/master/pkgs/build-support/darwin)
