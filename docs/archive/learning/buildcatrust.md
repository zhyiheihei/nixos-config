# buildcatrust 学习笔记

## 1. 是什么

`buildcatrust` 是 lukegb（与 Ryan Lahfa）写的信任库转换工具：把
Mozilla NSS 证书库转成其他格式，供 NixOS 下游系统使用。MIT，3
star，Python，2026-02 仍在维护。动机是现有工具会丢 NSS 的语义
（尤其 distrust-after 日期），它至少做到“不比现状更糟”，并尽量
保留信任位。

## 2. 设计目标

- **运行时零依赖**（只用 Python 标准库）——因为它在 NixOS 的
  bootstrap 路径里，加依赖会让“先有鸡还是先有蛋”更严重；
- 测试覆盖好（含非 hermetic 测试）；
- 尽量传达源库的信任位（必要时用 OpenSSL 等特定软件的 hack）。

## 3. 实现

- `nss_parser.py`：解析 Mozilla `certdata.txt`；
- `certstore_parser.py` / `certstore_output.py`：通用证书库
  解析/输出；`p11kit_output.py`：p11-kit 输出；
- `der_x509.py`：**自己解析 DER/X.509**（避免依赖）：
- `cli.py`：输出到文件、目录或 hashed dir；还有
  `tools/parse_axeman_csv.py` 等辅助。

## 4. 工程与发布

- `pyproject.toml`：flit 构建，console script `buildcatrust`，
  Python >= 3.11；
- pre-commit：ty（类型检查）、reuse（SPDX）、ruff check/format；
- CI：`pre-commit run --all` + `pytest`，cachix `buildcatrust`；
- 发布：打 tag → flit build → 用 trusted publishing 发 PyPI +
  Sigstore 签名 → 建 GitHub Release 并上传签名。

## 5. 对我们仓库的启发

- 我们直接用 nixpkgs 的 cacert，不引入；
- “bootstrap 路径工具必须零运行时依赖”是 NixOS 关键约束，也是
  它坚持手写 DER 解析的原因；写系统级基础工具时可借鉴；
- 它解释了 NixOS 证书库链路的来源，和我们的
  `environment.etc.ssl/certs` 配置直接相关。

## 6. 参考

- [buildcatrust](https://github.com/nix-community/buildcatrust)
