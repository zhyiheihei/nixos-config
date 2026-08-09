# image-spec（社区 fork）学习笔记

## 1. 是什么

`nix-community/image-spec` 是 [opencontainers/image-spec](https://github.com/opencontainers/image-spec)
的 fork（Apache-2.0，0 star）。compare 显示：**0 个领先提交**、
落后上游 225 个提交——只是 2022-11 的静态快照，无独立改动。

## 2. 结论

- OCI Image Format 规范与我们构建 OCI 镜像直接相关，但要用就用
  官方仓库，而不是这个 fork；
- 与 nix / nixpkgs / travis-build fork 同类，记录即可。

## 3. 对我们仓库的启发

- 我们构建容器镜像依赖 dockerTools / OCI 规范，参考上游
  opencontainers/image-spec；
- 再次验证：fork 的领先提交数为 0 时不需要深入阅读。

## 4. 参考

- [nix-community/image-spec](https://github.com/nix-community/image-spec)
