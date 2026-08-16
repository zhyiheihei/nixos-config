# dreampkgs 学习笔记

## 1. 是什么

`dreampkgs` 是 DavHau 用 [dream2nix](https://github.com/nix-community/dream2nix)
维护的包集合（beancount、gpt-engineer、healthchecks、home-assistant、
logchecker、crabfit-api/frontend），30 star，MIT。定位是 dream2nix
的试验田：目标就是测试并改进 dream2nix，两者都明确标 unstable。

CI 跑在 buildbot.nix-community.org 的 project 2。

## 2. Flake 接线

```nix
packages = eachSystem (system: dream2nix.lib.importPackages {
  projectRoot = ./.;
  projectRootFile = "flake.nix";
  packagesDir = ./packages;
  packageSets.nixpkgs = nixpkgs.legacyPackages.${system};
  packageSets.dreampkgs = self.packages.${system};  # 包之间可互相引用
  specialArgs = { inherit inputs; };
});
```

`checks` 把每个包都变成 check（aarch64-darwin 上排除 home-assistant，
因为 sandbox 环境变量太长）。

## 3. 包定义：NixOS 模块风格

每个包是 `packages/<name>/default.nix`，import dream2nix 模块：

```nix
{
  config, dream2nix, ...
}: {
  imports = [ dream2nix.modules.dream2nix.pip ];
  deps = {nixpkgs, ...}: { python = nixpkgs.python3; ... };
  name = "beancount";
  version = "3.0.0";
  pip.requirementsList = ["${config.name}==${config.version}"];
  ...
}
```

常用字段：`name` / `version` / `deps` / `mkDerivation`（任意
`stdenv.mkDerivation` 属性）、`pip.requirementsList`、
`pip.requirementsFiles`、`pip.pipFlags`、`pip.nativeBuildInputs`
（锁定阶段也要的构建依赖）、`pip.overrides`（按包名细调）、
`buildPythonPackage.*`。锁定结果按系统存
`lock.x86_64-linux.json` / `lock.aarch64-darwin.json`。

## 4. 几个有代表性的包

- **beancount**：pip 模块 + `--no-binary` + meson-python 原生构建，
  展示纯 PyPI 包的标准写法；
- **healthchecks**：不是真正的 Python 包（只有 repo +
  requirements.txt），用 `buildPythonPackage.format = "other"` +
  `flattenDependencies` + 自定义 installPhase/makeWrapper；还演示
  `pip.nativeBuildInputs`（psycopg2/pycurl 锁定期需要）和
  `pip.overrides`；
- **home-assistant**：几百个依赖的大树，`requirementsFiles` 由
  `update-requirements.sh` 从上游抓取，`pip.drvs` 里对
  aiokafka/pygatt/miniaudio/watchdog 等逐个 patch/补输入，`postPatch`
  放宽 wheel/setuptools 版本，还示范把依赖合成 `buildEnv` 塞进
  propagatedBuildInputs 规避环境变量溢出；
- **gpt-engineer**：WIP PDM 模块，`pdm.lockfile` +
  `pdm.pyproject`，并通过 `packageSets.dreampkgs` 自引用同一 flake
  里的 gpt-engineer 包，最后 wrapProgram 加
  `NODE_OPTIONS=--openssl-legacy-provider`。

## 5. CI / 发布

- buildbot 的 `nix-eval` 是合并门禁（Mergify queue_rules 要求
  `check-success=buildbot/nix-eval`）；
- `publish.yml`：打 `v*` tag 时用 flakestry 发布 flake；
- 只有 `.github/workflows/publish.yml` 一个 GitHub Actions。

## 6. 对我们仓库的启发

- 我们不直接用 dream2nix，但 zhyi-packages 若想自动打包 pip/PDM
  应用，这套 `default.nix` + lock 的写法比手写 buildPythonPackage
  省很多；
- “包之间互相引用（packageSets.dreampkgs 自引用）”和
  “锁定期依赖与构建期依赖分开配”是两个值得记住的设计；
- 它是 dream2nix（已学）的活体测试集，和上游文档互补。

## 7. 参考

- [dreampkgs](https://github.com/nix-community/dreampkgs)
- [dream2nix](https://github.com/nix-community/dream2nix)
