# trustix 学习笔记

## 1. 是什么

`trustix` 是一个 **去中心化构建透明/可复现性追踪** 的参考实现
（Go，364 star，未归档）。它要解决的问题是：Nix 用户使用
`cache.nixos.org` 这类集中式 binary cache 时，只要 Hydra 的签名私钥
或构建硬件被攻破，整个缓存里的包都可以被替换成恶意二进制，而且
一次密钥泄露相当于全部包都不可信。

Trustix 的思路是让一批独立 builder 各自签一个只能追加的构建日志，
对同一个 derivation 的输出 NAR hash 做“M-of-N 投票”，用户按自己的
安全要求决定多少个独立提供者一致才信任某个二进制。项目由 Tweag
开发，受 NLNet 的 NGI0 PET 基金资助，官方博客还把它和后来 JFrog
的 Pyrsia 列为同类项目。

## 2. 仓库结构

这是一个 Go monorepo（`flake-parts` 管理），主要子包：

- `packages/trustix`：核心 daemon，纯日志/决策逻辑，不依赖任何
  Nix 具体格式；
- `packages/trustix-nix`：给核心加 Nix 语义的补充 daemon：
  post-build hook、binary cache proxy、submit-closure 开发工具；
- `packages/trustix-nix-r13y`：基于日志实现的可复现性追踪服务
  （reproducibility tracker），带 SQLite 和 Web API；
- `packages/trustix-nix-r13y-web`：SolidJS + Vite 前端；
- `packages/trustix-proto`：所有 protobuf 定义和生成代码，用
  Connect/gRPC；
- `packages/trustix-doc`：mdBook 文档，CI 里发布到 GitHub Pages。

## 3. 日志与密钥模型

- 每个 builder 先生成 ed25519 密钥对，`trustix generate-key`；
- 日志 ID 不是随机值，而是按
  `protocol ID + mode + keyType + pubkey` 计算出的确定性 hash，
  `trustix print-log-id --protocol nix --pubkey ...` 可查；
- 每个日志由 signer 签名，保存为 append-only 的 verifiable log：
  普通追加日志 + Sparse Merkle Tree 键值映射 + 一个记录映射树根的
  “maphead” 日志；
- `LogHead` 同时带上日志根、映射根、各自 tree size 和签名；API
  提供 audit proof（包含性证明）和 consistency proof（历史一致性
  证明），所以即使签名密钥泄露，篡改历史也会被检测出来；
- 状态用 bbolt 持久化到 `trustix.db`。

## 4. 决策引擎

daemon 对同一个 key 汇总各日志结果后交给 decider，支持三种引擎：

- `percentage`：同输出 hash 的日志数占全部日志数的百分比达到阈值
  （例如 66%）才信任；
- `logid`：指定信任某个日志 ID；
- `javascript`：用 goja 执行用户函数，自行聚合日志结果。

多个 decider 可以串成 aggregate，返回第一个有结论的；`Decide` 响应
还带 `Mismatches`（hash 不一致的日志）和 `Misses`（没有记录的日志），
用来定位行为异常的 builder。

## 5. Nix 集成

`trustix-nix` 有两个主要入口：

- `post-build-hook`：读 `OUT_PATHS`，用 `nix path-info --json` 取
  NAR hash 和引用，把 `storePath -> narinfo JSON` 的键值对提交给
  daemon 的日志；
- `binary-cache-proxy`：本地提供标准 binary cache HTTP 服务。收到
  `.narinfo` 请求时先问 daemon `Decide`，只把达成共识的结果返回，
  并且用本地 binary cache 私钥重新签名；`/nar/` 内容则按日志里
  的 `upstream` meta 从多个缓存里拉取。因此 Nix 客户端可以把它当
  一个普通 substituter 用。

NixOS module（`services.trustix`、`services.trustix-nix-build-hook`、
`services.trustix-nix-cache`）都是 socket-activated + `DynamicUser`；
配置里用 `builtins.readFile` 读 pubkey，私钥路径默认从 `/nix/store`
之外的地方引用（否则会泄进 store）。

## 6. 可复现性追踪器 r13y

`trustix-nix-r13y` 把 Trustix 日志变成可查询的可复现性看板：

- 定时从 Hydra API 拉 jobset evaluation，重建 NIX_PATH，用
  `nix eval` 批量求出 attr -> derivation 映射；
- 把 derivation、递归依赖、输出和日志结果索引进 SQLite
  （sqlc 生成查询），派生路径上做引用计数和缓存；
- API 把某 derivation 的输出按日志分组，分成
  Reproduced / Unreproduced / Unknown / Missing 四类，还提供
  时间序列和 diffoscope HTML diff；
- Web 前端用 SolidJS + Tailwind/daisyUI + Chart.js；
- NixOS module 用 nginx 托管静态页并把 `/api` 反代到本地服务。

## 7. CI 与工程习惯

- `nix-github-actions` 从 flake 生成 Linux/Darwin 构建矩阵；
- 单独跑 gomod2nix 一致性检查、golangci-lint 和 `reuse lint`
  （SPDX 许可证）；
- `doc.yml` 构建 mdBook 后部署 GitHub Pages；
- flake 里 NixOS test 目前被注释掉，注释写明“临时注释让 CI 通过”；
- 开发用 hivemind 按 Procfile 同时跑所有子包，dev 密钥直接入库
  方便快速体验。

## 8. 对我们仓库的启发

- “集中式签名缓存是单点信任”这个分析依然成立；我们自建缓存时
  应当记录密钥管理边界，而不是只复制 `trusted-public-keys`；
- 确定性 log ID、可审计追加日志、M-of-N 决策是构建供应链安全的
  可复用模型；
- NixOS 服务模块的写法（socket activation、DynamicUser、密钥不放
  /nix/store）和我们 host 级模块风格一致。

## 9. 参考

- [trustix](https://github.com/nix-community/trustix)
- [Tweag 公告：Trustix](https://www.tweag.io/blog/2020-12-16-trustix-announcement/)
- [Trustix Trees](https://www.tweag.io/blog/2022-01-14-trustix-trees/)
- [Trustix Voting](https://www.tweag.io/blog/2022-02-03-trustix-voting/)
