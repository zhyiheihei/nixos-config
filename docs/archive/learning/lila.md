# lila 学习笔记

## 1. 是什么

`lila` 是 Nix 的“构建 hash 收集”基础设施：本地每次构建后，
post-build-hook 把输出的 NAR hash 签名上传到聚合服务器，用来跨
多个可信 builder 对比构建产物是否可复现。维护者 JulienMalka /
raboof，52 star，EUPL-1.2。公共实例在
[reproducibility.nixos.social](https://reproducibility.nixos.social)。

三个组成部分：

1. **post-build-hook**（Rust）：每次 Nix 构建后发布签名 attestation；
2. **服务器**（Python FastAPI）：聚合 hash；
3. **工具**：`rebuilder`、`copy-from-cache`、`diff-hook` 等。

## 2. 接入方式

flake 提供 `nixosModules.hash-collection`，加到主机后配置：

```nix
services.hash-collection = {
  enable = true;
  collection-url = "https://reproducibility.nixos.social";
  tokenFile = "/etc/hash-collection.token";
  secretKeyFile = "/etc/hash-collection-secret.key";  # nix key generate-secret
};
```

模块内部：

- 引入 `queued-build-hook` 模块，把 `build-hook` 包装成异步重试任务
  （`retryInterval` / `retries` / `concurrency` 可调）；
- 配置 `nix.settings.diff-hook` + `run-diff-hook`，用于
  `nix build --rebuild` 场景；
- token 和签名私钥从文件读取，不写进 Nix store。

## 3. Rust utils 与 patched Nix

`utils/` 是 Rust 工具集，通过 FFI 直接调用 Nix C API
（`libnixstorec` / `libnixutilc`）。为了让钩子能拿 NAR hash、大小、
references，仓库带了一个 `patched-nix`：

```nix
nixVersions.git.appendPatches [ ./nix-expose-apis.patch ]
```

补丁给 libstore-c 增加 `nix_store_path_nar_hash` /
`nix_store_path_nar_size` / `nix_store_path_references`，还给
nixutilc 暴露 `hash_path` / `sign_detached`。

`build-hook.rs` 的逻辑：

1. 从环境变量读 `OUT_PATHS`、`DRV_PATH`、token、secret key；
2. 对每个输出算 `nar_hash`、`nar_size` 和 references；
3. fingerprint = `1;out_path;nar_hash;size;references`，用 Nix
   key 做 detached signature；
4. POST `/api/attestation/<drv_hash>`。

其他工具：

- `diff-hook`：对 `--rebuild` 的新产物用 `hash_path` 算 hash 并上报
  （签名留空，注释说明 diff-hook 环境里没有 daemon 连接）；
- `rebuilder`：从 `/api/evaluations/<id>/suggest` 拉待重建列表，
  用 `MAX_CORES` 个线程并行跑 `nix build <drv>^<output>` 再
  `--rebuild`，统计成功/失败，不自动重试；
- `copy-from-cache`：直接从二进制缓存（默认 cache.nixos.org）读
  `.narinfo` 的 NarHash/Sig 上传，免构建就能补 attestation。

## 4. 服务器

`web/` 是 FastAPI + SQLAlchemy + Alembic + Jinja2（前端 htmx +
Tailwind），PostgreSQL 后端：

- 模型：`Derivation` / `User` / `Token` / `Attestation`（带
  `uploaded_at` 和签名/哈希字段）；
- API：`jobsets` / `evaluations` / `attestations` / `signatures`；
- 一个 evaluation 由 **CycloneDX SBOM** 定义：构建期闭包用
  `nix-build-sbom` 生成，运行期闭包用
  `nix-runtime-tree-to-sbom`（信号比更高，可能漏掉构建期拷贝的
  产物）；
- `/{user}/{digest}.narinfo` 端点把 attestation 渲染成标准 narinfo，
  让普通 Nix 客户端也能看；
- NixOS 模块 `services.lila`：Postgres + nginx 反代，
  `SQLALCHEMY_DATABASE_URL` 可配。

## 5. 对我们仓库的启发

- 我们有多 builder（ml-builder 等）但没有可复现性验证需求，
  暂不引入；
- 如果以后要给多台 builder 做“同 derivation 多机器对拍”，lila
  的“post-build-hook + 签名 attestation + suggest API”是现成骨架；
- “用补丁给 Nix C API 加方法再 FFI 调用”是 Rust 工具深度集成
  Nix 的路线，比每次 spawn `nix-store` 更高效，但需要维护
  patched-nix，成本不低。

## 6. 参考

- [lila](https://github.com/nix-community/lila)
- [r13y / nix-reproducible-builds-report](https://codeberg.org/raboof/nix-reproducible-builds-report/)
