# review-bot 学习笔记

## 1. 是什么

`review-bot` 是 ckiee 写的 Matrix bot：在 Matrix 房间里触发
`nixpkgs-review pr`（Mic92 的 nixpkgs PR 审查工具）并回报结果。
Apache-2.0，1 star，TypeScript + Nix，2022-05 后基本停更；README
自称“周末项目稳定性”。

## 2. 实现

- `src/index.ts` + `src/commands/`：Matrix 客户端（matrix-js-sdk）
  监听命令，把 PR 号转给 nixpkgs-review；
- `src/config.ts` + `config/default.yaml`：bot 配置；
- flake 用 yarn2nix（`yarn.nix` 锁依赖）构建，`wrapProgram`
  把 `nixpkgs-review-sandbox` 和 git 加进 PATH；
- NixOS module `services.nc-review-bot`：`secretFolder` 指向含
  `default.yml` 的密钥目录，用 `svc-util.nix` 起 systemd 服务。

## 3. 对我们仓库的启发

- 我们不做 Matrix 审查 bot，不引入；
- 它把“审查工具 + 消息接口 + systemd 部署”串起来，是 org 运维
  bot 的简单样例；
- `nixpkgs-review` 本身（Mic92 的独立项目）才是重点，bot 只是它
  的遥控器。

## 4. 参考

- [review-bot](https://github.com/nix-community/review-bot)
