# ethereum.nix 学习笔记

## 1. 是什么

`ethereum.nix` 是 Ethereum 生态的 Nix 包 + NixOS module 集合：执行层
客户端、共识客户端、验证器、MEV、SSV、staking 工具和 L2/OP 栈等，
当前 72 个包，MIT 协议，154 star。

## 2. 包集合

- 执行客户端：geth、reth、erigon、besu、nethermind、ethrex、nitro；
- 共识客户端：prysm、lighthouse、teku、lodestar、grandine、nimbus；
- 验证器：vouch、charon、dirk、web3signer、ethdo；
- MEV：mev-boost、mev-boost-relay、blutgang；
- 其他：foundry、anchor、eigenlayer、ethstaker-deposit-cli、
  kurtosis、helios、checkpointz 等。

包结构统一为 `packages/<tool>/package.nix`（定义）+ `default.nix`
（wrapper）+ 可选 `update.py`；meta 强制要求 description、homepage、
license、sourceProvenance、maintainers、mainProgram、platforms，
并用 `passthru.category` 组织 README。

## 3. NixOS modules

- 目前提供 geth、erigon、besu、geth-bootnode 模块；
- 用 `services.ethereum.<client>` 的 `attrsOf submodule` 支持多个
  实例；
- `settings` 是 freeform，扁平 dotted key 直接映射 CLI 参数
  （`lib.cli.toCommandLine`）；
- 共享 `baseServiceConfig`：DynamicUser + 全套 Protect*/Restrict*
  硬化，并按端口自动开防火墙；
- `disabledModules` 禁用 nixpkgs 自带的旧 geth 模块，避免冲突。

## 4. 工程与 CI

- flake 用 numtide/blueprint 组织，支持 aarch64/x86_64 Linux 和
  aarch64-darwin，`allowUnfree = true`；
- README 的包文档由 `scripts/generate-package-docs.py` 自动生成；
- 更新策略：优先 `nix-update`，只有复杂版本/非 GitHub 来源才写
  自定义 `update.py`；
- `update.yml` 每天两次跑可复用 `_updater.yml`，用 GitHub App token
  开 PR 并自动合并；`bot.yml` 处理 `/rebase` 等评论命令（校验
  write 权限）；
- formatter 用 treefmt：nixfmt/deadnix/statix/shellcheck/mdformat/ruff。

## 5. 对我们仓库的启发

- 我们目前用 podman 跑服务，不跑 Ethereum 节点；如果以后要
  自建执行/共识客户端或验证器，ethereum.nix 是现成选择；
- 它的 AGENTS.md 规范和 zhyi-packages 很像：meta 必填、
  nix-update 优先、分类组织 README，可以继续对照完善；
- `settings → CLI 参数 + 硬化 systemd base` 的模块模式值得参考。

## 6. 参考

- [ethereum.nix](https://github.com/nix-community/ethereum.nix)
- [Ethereum](https://ethereum.org)
