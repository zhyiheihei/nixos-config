# bundix 学习笔记

## 1. 是什么

`bundix` 是 Ruby gem，把 `Gemfile.lock` 转成 `gemset.nix`，供 nixpkgs
的 `bundlerEnv` 使用。作者 Michael Fellinger（manveru），最初由
Alexander Flatter 编写，MIT 协议，当前版本 2.5.0，183 star。仓库由
nix-community 维护，最后一次改动约在 2023 年。

## 2. 用法

```bash
bundix -l          # 先锁 Gemfile.lock，再生成 gemset.nix
```

然后写 `default.nix`：

```nix
let
  gems = bundlerEnv {
    name = "your-package";
    inherit ruby;
    gemdir = ./.;
  };
in stdenv.mkDerivation {
  name = "your-package";
  buildInputs = [ gems ruby ];
}
```

其他选项：`-i/--init` 生成 `shell.nix` 模板，`-m/--magic` 先
`bundle lock` + `bundle pack` 再生成，`--gemset/--lockfile/--gemfile`
可指定路径。

## 3. 实现要点

- 用 `Bundler::LockfileParser` 解析 lock 文件，遍历每个 gem；
- 对每个 gem 先找本地 bundle cache（`bundle package` 的产物），再
  遍历 remote 下载，用 `nix-prefetch-url` / `nix-prefetch-git` +
  `nix-hash` 计算 sha256；
- 如果已有 `gemset.nix`，先 `nix-instantiate --eval` + JSON 解析，
  复用已有 hash，增量更新只需几秒；
- 支持 rubygems / git / path 三种 source，记录 platforms 和 groups；
- `Nixer` pretty printer 保证输出稳定，方便审计 diff；
- `default.nix` 用 `makeWrapper` 给 PATH 加上 nix、
  nix-prefetch-git、bundler，并设置 `GEM_PATH`。

## 4. 测试

- minitest：Nixer 序列化、Fetcher 的 HTTP 认证/重定向、
  CommandLine 的 `shell.nix` 模板；
- 没有 GitHub Actions，测试靠 Rakefile 在 nix-shell 里跑。

## 5. 对我们仓库的启发

- 我们目前没有 Ruby 包；如果以后 zhyi-packages 要加 Ruby 应用，
  nixpkgs `bundlerEnv` + bundix 是现成路线；
- 可借鉴“先解析已有输出复用 hash，再做增量生成”的更新策略，和
  `gomod2nix` 的 hash cache 思路类似。

## 6. 参考

- [bundix](https://github.com/nix-community/bundix)
- [nixpkgs Ruby manual](https://nixos.org/nixpkgs/manual/#sec-language-ruby)
