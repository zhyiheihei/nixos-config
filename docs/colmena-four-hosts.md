# 使用 Colmena 构建和部署四台主机

本文适用于以下四个 NixOS 配置：

- `ml-builder`
- `ml-builder-cache`
- `ml-2700u`
- `pve-2700u`

所有命令优先在 `ml-builder` 上运行，仓库路径为：

```bash
cd /nix/src/nixos-config
git pull --ff-only
```

## 最常用的短命令

```bash
# 只求值四个配置，不构建、不部署。
make four-eval

# 构建四个配置，不部署。这是推荐先运行的命令。
make four

# 部署并切换当前在线的三台 NixOS。
make current
```

`make four` 会同时构建 `ml-builder`、`ml-builder-cache`、`ml-2700u` 和
`pve-2700u`，但不会连接远端切换系统。

`make current` 会直接部署并切换 `ml-builder`、`ml-builder-cache` 和
`ml-2700u`。这是有实际系统变更的命令。

如果 `ml-builder` 尚未切换到包含 GNU Make 的新配置，可以临时运行：

```bash
nix shell nixpkgs#gnumake -c make four
```

## 重要区别

仓库中的 `make all` 不是“构建全部主机”，而是：

```bash
nix run .#colmena -- apply --on @default
```

`apply` 会构建、上传并切换远端系统。它不是只读测试。

四台主机目前都设置了 `manualDeploy = true`，因此不会进入
`@default` 自动部署组。此外，`ml-2700u` 和 `pve-2700u` 当前代表同一台
物理设备的两种系统配置，不能在一次部署中同时切换。

可以同时构建四个配置，但部署时只能选择当前实际安装在 2700U 上的那个配置。

## 1. 只做求值

求值四个配置，不构建，也不连接远端切换系统：

```bash
nix run .#colmena -- eval \
  --on ml-builder,ml-builder-cache,ml-2700u,pve-2700u
```

这一步适合检查 Flake、模块和 Colmena 主机选择是否正常。

## 2. 构建四个配置

构建四个系统闭包，但不部署：

```bash
LOG="/root/colmena-four-hosts-$(date +%Y%m%d-%H%M%S).log"

nix run .#colmena -- build \
  --on ml-builder,ml-builder-cache,ml-2700u,pve-2700u \
  2>&1 | tee "$LOG"

echo "LOG=$LOG"
```

查看错误：

```bash
grep -Ein 'error:|failed|out of memory|oom|killed|timeout|bad gateway' "$LOG"
```

查看实时进度：

```bash
tail -f "$LOG"
```

这条命令可以安全地包含 `ml-2700u` 和 `pve-2700u`，因为它只构建，不切换设备。

## 3. 部署当前在线的三台 NixOS

在 2700U 仍运行 `ml-2700u` 时：

```bash
nix run .#colmena -- apply \
  --on ml-builder,ml-builder-cache,ml-2700u
```

这会构建并切换三台机器。不要在这个命令中加入 `pve-2700u`。

## 4. 2700U 改装 PVE 后部署

只有当 2700U 已经按 `pve-2700u` 配置完成安装、SSH 地址也确认正确后，才运行：

```bash
nix run .#colmena -- apply --on pve-2700u
```

此后日常部署组合应改为：

```bash
nix run .#colmena -- apply \
  --on ml-builder,ml-builder-cache,pve-2700u
```

不要再同时部署 `ml-2700u`。

## 5. Hydra 自动构建

Hydra 的自动构建名单已经在 `flake.nix` 的 `hydraJobs` 中限定为这四个配置。
Git 仓库出现新提交后，Hydra 会按 Jobset 的 `Check interval` 拉取并构建：

```text
ml-builder
ml-builder-cache
ml-2700u
pve-2700u
```

Hydra 自动构建和 Colmena 部署是两件事：

- Hydra：持续集成，只生成系统闭包和缓存。
- Colmena `build`：手动构建选中的主机，不切换系统。
- Colmena `apply`：构建并部署、切换远端系统。

## 6. 查看全部 Make 命令

```bash
# 裸跑 make 和 make help 效果相同，都只显示帮助。
make
make help
```

下面是当前 Makefile 中所有可执行目标。

### 自有四主机命令

| 命令 | 实际操作 | 是否切换系统 |
| --- | --- | --- |
| `make four-eval` | 求值四个自有配置 | 否 |
| `make four` | 构建四个自有配置 | 否 |
| `make current` | 部署 `ml-builder`、`ml-builder-cache`、`ml-2700u` | 是 |

对应的四个构建配置是：

```text
ml-builder
ml-builder-cache
ml-2700u
pve-2700u
```

### Colmena 构建命令

| 命令 | 实际操作 | 是否连接远端 |
| --- | --- | --- |
| `make build` | `colmena build`，构建整个 Hive | 否 |
| `make build-default` | 构建 `@default` 选择器中的主机 | 否 |
| `make build-x86` | 构建 `@x86_64-linux` 选择器中的主机 | 否 |

`make build` 不等于只构建四台自有主机。它会选择当前 Colmena Hive 中的全部主机。
在仓库仍保留作者 host 时，优先使用 `make four`。

### Colmena 部署命令

| 命令 | 实际操作 | 风险 |
| --- | --- | --- |
| `make servers` | 部署并切换 `@server` | 高 |
| `make all` | 部署并切换 `@default` | 高 |
| `make all-all` | 部署并切换 `@all` | 很高 |
| `make all-boot` | 以 `boot` 模式部署 `@default` | 高 |
| `make all-reboot` | 部署并重启 `@default-non-local` | 很高 |
| `make all-all-reboot` | 部署并重启 `@non-local` | 很高 |

这些命令调用的是 `colmena apply`，不是单纯构建。执行成功后会改变远端机器状态。

选择器含义：

| 选择器 | 含义 |
| --- | --- |
| `@server` | 带 `server` 标签的主机 |
| `@default` | 默认允许自动部署的主机，通常排除 `manualDeploy = true` |
| `@all` | Hive 中的全部主机，包括手动部署主机 |
| `@x86_64-linux` | x86_64 Linux 主机 |
| `@non-local` | 排除执行命令的本地主机 |
| `@default-non-local` | 默认部署组中除本机外的主机 |

当前仓库仍有作者 host，并且自有四台都设置了 `manualDeploy = true`，因此不要把
`make all` 理解成“四台自动构建”。四台构建应使用：

```bash
make four
```

### 当前主机命令

| 命令 | 实际操作 | 风险 |
| --- | --- | --- |
| `make local` | 根据 `/etc/hostname` 部署并切换当前主机 | 高 |
| `make local-reboot` | 部署当前主机并立即重启 | 很高 |

例如在 `ml-builder` 上运行 `make local`，等价于：

```bash
nix run .#colmena -- apply --on ml-builder
```

### 清理命令

```bash
make clean
```

等价于：

```bash
nix run .#colmena -- exec -- nixos-cleanup
```

它会在 Colmena 选择的 Hive 主机上执行 `nixos-cleanup`，可能删除旧 generation
和不再使用的 Nix store 路径。执行前应确认当前系统 generation 正常。

### 更新命令

更新全部 Flake inputs，并运行 nvfetcher：

```bash
make update
```

它会修改 `flake.lock`，也可能更新 nvfetcher 生成文件，不应在准备部署前随意运行。

只更新 `nur-xddxdd`：

```bash
make update-nur
```

等价于：

```bash
nix flake update nur-xddxdd
```

### Attic 缓存命令

```bash
make push-cache
```

等价于：

```bash
attic push lantian $(readlink -f .gcroots/*)
```

它只推送 `.gcroots/` 中记录的闭包，不会自动推送整个 `/nix/store`。运行前需要：

- 已安装并登录 `attic` 客户端。
- 已配置名为 `lantian` 的缓存。
- `.gcroots/` 中存在有效链接。

### 命令风险速查

```text
只读/安全：make help, make four-eval
只构建：   make four, make build, make build-default, make build-x86
会部署：   make current, make servers, make all, make all-all, make all-boot
会重启：   make all-reboot, make all-all-reboot, make local-reboot
会清理：   make clean
改锁文件： make update, make update-nur
推送缓存： make push-cache
```

如果系统没有安装 `make`，可以临时使用：

```bash
nix shell nixpkgs#gnumake -c make help
nix shell nixpkgs#gnumake -c make four
```

## 推荐日常流程

```bash
cd /nix/src/nixos-config
git pull --ff-only

# 先求值，快速发现配置错误。
make four-eval

# 构建全部四个自有配置，不部署。
make four

# 构建成功后，部署当前在线的三台 NixOS。
make current
```

等 2700U 正式改成 PVE 后，将最后一个主机名从 `ml-2700u` 换成
`pve-2700u`。
