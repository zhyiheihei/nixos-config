# nixpkgs-terraform-providers-bin 学习笔记

## 1. 是什么

`nixpkgs-terraform-providers-bin` 由 Numtide 维护（60 star，状态
stable）：每天把
[registry.terraform.io](https://registry.terraform.io/browse/providers)
上最新版 Terraform/OpenTofu provider 的官方二进制 zip 打包成 Nix
derivation，兼容 `terraform.withPlugins` / `opentofu.withPlugins`。

典型用途：项目被旧 nixpkgs channel 卡住时，用它拿最新 provider，
和 nixpkgs 自带的 provider 混用。

## 2. 命名与目录结构

顶层 namespace 与 HashiCorp registry 一一对应，`/` 换成 `.`：

```nix
nixpkgs-terraform-providers-bin.providers.hashicorp.nomad
# 对应 registry.terraform.io/providers/hashicorp/nomad
```

磁盘结构：

```text
providers/
  hashicorp/
    nomad/default.json   # archSrc/owner/repo/version
```

这样同名不同 owner 的 provider 也能共存。

## 3. 构建模型

`default.nix` 的 `mkTerraformProvider` 很直接：

```nix
stdenv.mkDerivation {
  pname = "terraform-provider-${repo}";
  inherit version;
  src = fetchArchURL system archSrc;   # 按当前系统取 url+sha256
  unpackPhase = "unzip -o $src";
  buildPhase = ":";
  installPhase = ''
    dir=$out/libexec/terraform-providers/${provider-source-address}/${version}/${GOOS}_${GOARCH}
    mkdir -p "$dir"
    mv terraform-* "$dir/"
  '';
}
```

关键点：

- 用 registry API 给出的官方二进制 zip，不本地编译；
- 安装目录严格按 Terraform 的
  `libexec/terraform-providers/<registry>/<owner>/<repo>/<version>/<GOOS>_<GOARCH>/`
  布局，`withPlugins` wrapper 才能发现；
- `archSrc` 覆盖 aarch64/x86_64 linux/darwin 和 i686-linux 五种平台；
- 非 flake 导入时，`flake.lock.nix`（flake-compat 的“只返回
  inputs”变体）负责固定 nixpkgs。

## 4. 自动更新

`update.rb`（Ruby，跑在 `nix-shell -i ruby`）：

1. 请求 registry API `/v1/providers/<owner>/<repo>/versions`；
2. 过滤掉 alpha/beta 等非稳定版本，只留 `x.y.z`（可带 `-数字`
  后缀）并排序；
3. 对每个平台再查 `/download/<os>/<arch>` 拿 download_url 和
   shasum；
4. 把 `amd64/arm64/386` 和 `linux/darwin` 映射成 Nix system 名；
5. 只有版本变化才写 `default.json`，减少噪声。

## 5. CI 与测试

两个 GitHub Actions：

- `nix.yml`：push/PR 时在 ubuntu + macos 矩阵跑 `ci.sh`
  （`nix-build release.nix`、`nix flake check`、example 的
  flake/shell 检查）；
- `cron.yml`：每天 UTC 0 点先 `./update.rb` 更新所有 provider，
  再跑 `ci.sh`，最后用 `actions-js/push` 自动提交回 master。

功能测试在 `test/file/`：用 `opentofu.withPlugins` 组装 local/null
provider，在 `runCommand` 里真实执行 `tofu init && tofu apply
-auto-approve`，再断言生成的 `foo` 文件内容为 `bar`；另一个用例
验证 `required_providers` 声明方式。flake 的 `checks` 还包含
`treefmt` 格式检查。

## 6. 对我们仓库的启发

- 我们没有 Terraform 需求，不引入；
- “每天 cron 拉 registry API → 自动生成 package set → CI 验证 →
  自动提交”是一套可复制的“二进制软件目录”维护模式，和我们的
  nvfetcher + DNSControl 更新链路思路一致；
- `withPlugins` 兼容的安装目录布局是给 Terraform 系工具打包的
  硬约束，以后若在 zhyi-packages 补 Terraform 生态可直接照抄。

## 7. 参考

- [nixpkgs-terraform-providers-bin](https://github.com/nix-community/nixpkgs-terraform-providers-bin)
- [Terraform registry API](https://developer.hashicorp.com/terraform/registry/api-docs)
