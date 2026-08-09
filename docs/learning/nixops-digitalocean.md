# nixops-digitalocean 学习笔记

## 1. 是什么

`nixops-digitalocean` 是 NixOps 的 DigitalOcean 后端插件（org
维护者 @Kiwi，pyproject 作者 Robert Djubek / Matan Shenhav，LGPL-3.0，
18 star，Python，2024-04 后停更）：让
`deployment.targetEnv = "droplet"` 的机器由 NixOps 管理。

依赖 `python-digitalocean`；选项：`authToken`（优先环境变量
`DIGITAL_OCEAN_AUTH_TOKEN`）、`region`、`size`、`enableIpv6`。

## 2. 特殊实现：nixos-infect

后端注释写得很直白：DigitalOcean 没有现成 NixOS 镜像，所以：

1. 先创建 Ubuntu 16.04 droplet（“only for lustration”）；
2. 上传并运行修改版 **nixos-infect**（NixOS LUSTRATE 机制），把
   Ubuntu 现场替换成 NixOS；
3. 需要两次重启：infect 一次，推完 NixOS 镜像再一次。

改 nixos-infect 的原因（注释列出）：

- DO 不做 DHCP，网络配置必须硬编码；
- Ubuntu 用 `eth0` 而重启后 NixOS 用 `ens3`，要处理网卡名变化；
- 修改为不自动 reboot，避免 SSH 中断导致部署报错。

`get_physical_spec` 保留 Ubuntu bootloader（`nodev`），避免替换
引导链。

## 3. Python 后端

`backends/droplet.py`：

- `DropletDefinition`：从配置取 auth/region/size/ipv6；
- `DropletState`：`public_ipv4` / `public_ipv6` / 网关等全部
  `attr_property` 持久化；`_get_droplet` 用 digitalocean SDK；
- `create`：建 droplet、SSH key pair、跑 nixos-infect、写网络
  配置；`destroy` 删 droplet；SSH 走 public_ipv4 + known_hosts。

## 4. Nix 模块与 CI

- `nix/droplet.nix`：选项 + 实现（`nixpkgs.system =
  "x86_64-linux"`、openssh 开启）；`nix/default.nix` 提供
  options + config_exporters；
- CI 很全：nix 解析、nix-build、black、nixpkgs-fmt、mypy、
  flake8、`mypy-ratchet`（用 `ci/ratchet.py` 控制错误数）、
  coverage、Sphinx docs lint、poetry lock 一致性；
- 功能测试是**真实打 DO droplet**：start/stop、IPv6、rollback、
  deploy NixOS（`tests/functional/*.py` + `coverage-tests.py`）；
- 有独立的 `nixops-digitalocean` cachix。

## 5. 对我们仓库的启发

- 我们不用 DigitalOcean，不引入；
- “云上没有 NixOS 镜像就 infect”是一条通用思路（nixos-infect /
  nixos-anywhere 都源于此）；我们装机用 nixos-anywhere，思想同源；
- 它的 CI 门禁（mypy ratchet、真实云资源功能测试）比其它 NixOps
  插件仓库更完整，做云工具时值得参考。

## 6. 参考

- [nixops-digitalocean](https://github.com/nix-community/nixops-digitalocean)
- [nixos-infect](https://github.com/elitak/nixos-infect)
