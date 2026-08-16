# goblin-signing 学习笔记

## 1. 是什么

`goblin-signing` 是 raitobezarius / baloo 的 Rust 库（MIT，2 star，
2024-02 后基本停更）：给 Goblin 加“签名 PE 二进制”能力，特别面向
PKCS#11。消费方是 [lanzaboote](https://github.com/nix-community/lanzaboote)
（已学）——用它实现 UEFI 二进制的 PKCS#11 签名。

## 2. 模块

- `authenticode.rs`：`Authenticode` trait，对 Goblin 提供的
  `authenticode_ranges()` 逐段做 hash（Authenticode digest）；
- `certificate.rs`：SPC_INDIRECT_DATA / SPC_PE_IMAGE_DATA OID、
  `DigestInfo` / `SpcIndirectDataContent`，用 `cms` 构造
  SignerInfo/SignedData；
- `sign.rs`：`create_certificate`——算 Authenticode digest →
  SPC indirect data → CMS SignedData + 证书链 + signer 签名，编码成
  PE 的 AttributeCertificate；
- `verify.rs`：从 PE 提取 SignedData + digest info，`verify_pe_signatures`
  按 trust store 校验（可忽略时间戳），收集所有非致命错误；
- `efi/`：EFI signature lists、变量等（UEFI db 更新用）。

## 3. 依赖

- 用 RaitoBezarius 的 goblin fork（`goblin-signing` 分支，提供
  `authenticode_ranges`）和 scroll patch；
- RustCrypto 栈（cms/der/x509-cert/ecdsa/ed25519/p256）+ cryptoki
  fork（PKCS#11）。

## 4. 开发与测试

- `default.nix` devShell 配 **SoftHSM**（softhsm2），提供
  `PKCS11_SOFTHSM2_MODULE` 和 token URI，方便本机跑 PKCS#11 测试；
- `tests/`：对 `nixos-uki.efi` 用 snakeoil 证书做签名/校验测试；
- `examples/`：`sign_binary` / `verify_binary`。

## 5. 对我们仓库的启发

- 我们不用 Secure Boot 签名，不引入；
- 它和 sigtool（Mach-O）一样属于“二进制签名”谱系，但走
  RustCrypto + PKCS#11，是 HSM 集成的好样板；
- “SoftHSM 放进 devShell 跑 PKCS#11 测试”对任何需要 HSM 的
  工具都有参考价值。

## 6. 参考

- [goblin-signing](https://github.com/nix-community/goblin-signing)
