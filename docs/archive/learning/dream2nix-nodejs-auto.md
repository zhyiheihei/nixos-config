# dream2nix-nodejs-auto 学习笔记

## 1. 是什么

`dream2nix-nodejs-auto` 是 DavHau 的 dream2nix 测试仓库：自动生成
npm 上**被依赖最多的 5000 个包**的 package set。MIT，1 star，Nix，
2022-11 已归档（功能并入 dream2nix-auto-test 系列）。

## 2. 结构与生成

- `flake.nix`：`dream2nix.lib.makeFlakeOutputsForIndexes` +
  libraries-io 索引（platform=npm，number=5000）；
- `packageOverrides` 把全部包 `buildScript = ":"`（只验证索引与
  锁定，不全量编译）；
- `checks = packages`；
- 数据在 **`data` 分支**，每天由 bot 更新；构建失败情况看该分支
  的 Hercules CI。

## 3. 对我们仓库的启发

- 我们不用 dream2nix，不引入；
- 它是 dream2nix-auto-test 的 Node.js 前身：同一套“top-N 索引 +
  自动生成 + 分数据分支 + CI”方法，后来被统一；
- 与 dream2nix-pypi-most-popular 一起，构成 dream2nix 多生态
  回归测试谱系。

## 4. 参考

- [dream2nix-nodejs-auto](https://github.com/nix-community/dream2nix-nodejs-auto)
