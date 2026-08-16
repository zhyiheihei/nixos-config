# nur-update 学习笔记

## 1. 是什么

`nur-update` 是 NUR 的更新触发服务（org 维护者 Pandapip1，作者
Jörg Thalheim，MIT，9 star，Python/Flask，2026-07 仍在维护）：提供
一个 HTTP 端点，通知 [NUR](https://github.com/nix-community/NUR)
去检查某个仓库是否有更新，有则更新 `repos.json.lock`。

```sh
curl -XPOST https://nur-update.nix-community.org/update?repo=mic92
```

## 2. 实现（nur_update/__init__.py）

- Flask 应用，PyGithub 连接 `nix-community/NUR`；
- 认证：优先 `GITHUB_TOKEN` 环境变量，否则 GitHub App
  （private key + app id + installation id 三件套）；
- `GET /`：用法说明页；
- `POST /update?repo=<name>`：
  1. 查 NUR main 分支最近一次 workflow run 的时间，**5 分钟内
     不再触发**（返回 429）；
  2. `repo` 参数缺失返回 400；
  3. `create_dispatch` 触发 NUR 的 `update.yml` workflow，返回
     204。
- 部署：`Procfile` 用 gunicorn 跑 `nur_update:app`（Heroku 风格），
  线上在 `nur-update.nix-community.org`。

## 3. 工程与 CI

- flake 用 nixpkgs `buildPythonApplication`（flask/gunicorn/
  pygithub），checkPhase 跑 `ruff check/format` + `mypy --strict`；
- GitHub Actions 只做 `nix build -L`；Mergify/Bors 队列负责合并
  （`tests` 绿）；
- renovate + dependabot 管依赖。

## 4. 与我们 NUR 注册的关系

- 我们的 zhyi-packages 已注册 NUR（PR #1197 等合并）：合并后 NUR
  的 evaluation 会定期拉取我们的仓库，不需要我们调这个端点；
- 如果以后我们想让 NUR **尽快**检查更新，可以
  `curl -XPOST https://nur-update.nix-community.org/update?repo=zhyiheihei`
  （注意 5 分钟限流）；
- 这个仓库也解释了 NUR 的自动更新链路：
  endpoint → workflow_dispatch → 更新 repos.json.lock → nur-search
  数据更新（已学 nur-search 的 update.yml 与这里呼应）。

## 5. 参考

- [nur-update](https://github.com/nix-community/nur-update)
