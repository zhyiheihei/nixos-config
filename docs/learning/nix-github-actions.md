# nix-github-actions 学习笔记

## 1. 是什么

`nix-github-actions` 是 Nix 库 + CI 模板，把 flake 的
`packages`/`checks` 按系统展开成 GitHub Actions matrix，实现“每个
attribute 一个 runner”。MIT 协议，155 star，主打 unopinionated：
它不是 action，而是一组模板和库。

## 2. 用法

在 flake 里加一个输出：

```nix
githubActions = nix-github-actions.lib.mkGithubMatrix {
  checks = self.packages;
};
```

然后把仓库自带的 workflow 模板复制到项目：

- `nix-matrix` job：`nix eval --json '.#githubActions.matrix'` 生成
  matrix 并写入 `GITHUB_OUTPUT`；
- `nix-build` job：`strategy.matrix` 来自 JSON，逐个
  `nix build -L .#<attr>`。

可以只对部分系统生成矩阵（例如 GHA 没有的 `aarch64-darwin` 排除）：

```nix
mkGithubMatrix {
  checks = nixpkgs.lib.getAttrs [ "x86_64-linux" "x86_64-darwin" ] self.checks;
}
```

## 3. 实现

- `default.nix` 提供 `githubPlatforms` 映射（x86_64-linux →
  ubuntu-24.04、aarch64-linux → ubuntu-24.04-arm、x86_64-darwin →
  macos-13、aarch64-darwin → macos-14）；
- `mkGithubMatrix` 把 `{ system = { attr = drv; }; }` 拍平成
  `matrix.include`，每项含 `name`、`system`、`os`、`attr`；
- `attrPrefix` 默认 `githubActions.checks`，可改成任意 flake 路径；
- `quickstart.py` 交互式复制模板并打印 flake 接入片段。

## 4. 与我们仓库的启发

- [tree-sitter-nix](./tree-sitter-nix.md) 就用它生成自己的 CI 矩阵，
  是 nix-community 内部常用模式；
- 我们 zhyi-packages 的 `build.yml` 目前是手写 matrix；如果以后
  checks 变多，可以改成“flake 里定义 checks + nix-github-actions
  生成矩阵”，避免 workflow 与 flake 双份维护。

## 5. 参考

- [nix-github-actions](https://github.com/nix-community/nix-github-actions)
- [tree-sitter-nix 学习笔记](./tree-sitter-nix.md)
