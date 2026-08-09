# poetry2nix 学习笔记

## 1. 是什么

`poetry2nix` 把 **Poetry 项目转成 Nix derivation**（927 star）。
它解析 `pyproject.toml` 和 `poetry.lock`，不需要手写 Python 包
表达式；Tweag 的 adisbladis 开发，曾是最主流的 Poetry 打包路线。

## 2. API

```nix
poetry2nix.mkPoetryApplication {
  projectDir = ./.;
}
```

主要 API：

- `mkPoetryApplication`：构建应用；
- `mkPoetryEnv`：构建带全部依赖的开发环境，支持 editable 包；
- `mkPoetryPackages`：暴露生成的所有包；
- `mkPoetryScriptsPackage`：只打包 `[tool.poetry.scripts]`；
- `mkPoetryEditablePackage`：editable 安装；
- `defaultPoetryOverrides`：修正 Python 包问题的内置 overrides；
- `overrides.withDefaults` / `withoutDefaults`：叠加自定义
  overrides；
- `cleanPythonSources`：清理 Python 项目源码目录。

## 3. 维护状态

README 明确标注 **Unmaintained**：

- 作者不再使用 Poetry / poetry2nix；
- 不计划支持 Poetry 2.0 和 PEP-621 metadata；
- 官方建议新项目考虑 `uv` + `uv2nix`。

所以它不是新项目的推荐起点，只适合已锁死 Poetry 1.x 的历史项目。

## 4. 对我们仓库的启发

`zhyi-packages` 的 Python 包直接用 nixpkgs `buildPythonPackage` +
`python3Packages`，没有用 poetry2nix：

- 我们包少且依赖由 nixpkgs 统一管理，原生路线维护成本最低；
- 如果未来出现必须用 Poetry lockfile 的项目，先评估 uv2nix，
  不要回头引入 poetry2nix；
- 它的“默认 overrides 集合”设计值得学习：给 Python 包做批量
  修正时，我们也应把补丁集中成 override 而不是散在包表达式里。

## 5. 参考

- [poetry2nix](https://github.com/nix-community/poetry2nix)
- [Tweag 公告](https://www.tweag.io/blog/2020-08-12-poetry2nix/)
- [language-packaging 总览](./language-packaging.md)
