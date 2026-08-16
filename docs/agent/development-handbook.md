# 开发操作手册（agent 干活参考）

> 本文从 AGENTS.md 拆出：agent 在仓库里做开发类改动（加模块/输入/overlay/端口）时按此操作。
> 规则与硬约束见 `AGENTS.md` 与 `work-norms.md`；模块分层见 `module-placement-norms.md`。

## 快速放置决策

| 要加的东西 | 放哪里 | 备注 |
| --- | --- | --- |
| 通用/角色 NixOS 模块 | `nixos/<role>-apps`、`nixos/<role>-components`、`nixos/minimal-modules` | 自动导入；新模块默认禁用，提供 `options.lantian.<name>` |
| 可选应用/硬件片段/定时任务 | `nixos/optional-apps`、`nixos/hardware`、`nixos/optional-cron-jobs` | 主机配置手动 `imports` |
| 主机专属覆盖/代理/vhost | `hosts/<host>` | 不写进公共模块 |
| 通用包/服务补丁 | `patches/<pkg>-<desc>.patch` | overlay 或 `nixos/` 模块显式引用 |
| Nixpkgs 补丁 | `patches/nixpkgs/<PR>.patch` | `nixpkgs-options.nix` 自动应用 |
| 板级内核补丁 | `nixos/hardware/<board>` 或 `pkgs/<kernel>` | 跟随使用方局部引用 |
| 自定义 Nix 包 | `pkgs/<name>` | 由 overlay 或 flake outputs 用 `callPackage` 引用 |
| 包覆盖/换实现 | `overlays/<NN>-<desc>.nix` | 数字前缀决定执行顺序 |
| 端口常量 | `helpers/constants/ports.nix` | 用 `LT.port.<Name>` 引用 |
| DNS 记录 | `dns/domains` | 通过 DNSControl 发布 |

## 新增 Flake 输入

### 步骤 1：在 flake.nix 中添加输入

在 [`flake.nix`](../../flake.nix) 的 `inputs` 块中添加新的输入。

**基本输入格式**：

```nix
input-name = {
  url = "github:owner/repo";
};
```

**带 follows 的输入格式**（共享依赖，避免重复下载）：

```nix
input-name = {
  url = "github:owner/repo";
  inputs.nixpkgs.follows = "nixpkgs";
  inputs.systems.follows = "systems";
};
```

**非 Flake 输入格式**：

```nix
input-name = {
  url = "https://example.com/file.tar.gz";
  flake = false;
};
```

### 步骤 2：使用 Flake 输入

**在 Flake 模块中导入**：

在 [`flake.nix`](../../flake.nix) 的 `imports` 列表中添加：

```nix
inputs.some-flake.flakeModules.someModule
```

**在 NixOS 模块中使用**：

通过 `inputs` 参数访问，例如在 [`helpers/default.nix`](../../helpers/default.nix) 中 `inputs` 已作为参数传入。

**在 Overlay 中使用**：

在 [`overlays/`](../../overlays) 目录下创建新的 overlay 文件，通过 `inputs` 参数访问 flake 输入。

### 步骤 3：更新 Flake 锁

```bash
nix flake lock --update-input input-name
```

## 添加 NixOS 模块

### 步骤 1：确定模块类型

根据模块用途选择目录：

| 模块类型   | 目录                        | 自动导入的配置          |
| ---------- | --------------------------- | ----------------------- |
| 最小化应用 | `nixos/minimal-apps`       | minimal, server, client |
| 通用应用   | `nixos/common-apps`        | server, client          |
| 服务器应用 | `nixos/server-apps`        | server                  |
| 客户端应用 | `nixos/client-apps`        | client                  |
| 最小化组件 | `nixos/minimal-components` | minimal, server, client |
| 可上游化模块 | `nixos/minimal-modules`  | minimal, server, client |
| 服务器组件 | `nixos/server-components`  | server                  |
| 客户端组件 | `nixos/client-components`  | client                  |
| Proxmox VE 组件 | `nixos/pve-components` | pve |
| 可选应用 | `nixos/optional-apps` | 需主机手动导入 |
| 硬件配置片段 | `nixos/hardware` | 需主机手动导入 |
| 可选定时任务 | `nixos/optional-cron-jobs` | 需主机手动导入 |

### 步骤 2：创建模块文件

在对应目录下创建 `.nix` 文件。`minimal-apps/`、`common-apps/`、`server-apps/`、
`client-apps/`、`minimal-components/`、`minimal-modules/`、`server-components/`、
`client-components/`、`pve-components/` 会被对应配置类型自动导入；
`optional-apps/`、`hardware/`、`optional-cron-jobs/` 不会被自动导入，需在主机
`configuration.nix` 的 `imports` 中手动引入。

自动导入机制：各配置文件（[`minimal.nix`](../../nixos/minimal.nix)、[`server.nix`](../../nixos/server.nix)、
[`client.nix`](../../nixos/client.nix)、[`pve.nix`](../../nixos/pve.nix)）使用 `builtins.readDir` 自动加载
对应目录下的所有 `.nix` 文件。

## 添加 Overlay

### 步骤 1：创建 Overlay 文件

在 [`overlays/`](../../overlays) 目录下创建新文件，命名格式为 `数字前缀-描述.nix`。

数字前缀决定执行顺序：

- `00-` 到 `39-`：基础配置
- `40-` 到 `59-`：包覆盖
- `60-` 到 `89-`：非 Flake 包
- `90-` 以上：优化和清理

### 步骤 2：编写 Overlay

```nix
# overlays/50-my-overlay.nix
final: prev: {
  # 覆盖现有包
  somePackage = prev.somePackage.overrideAttrs (old: {
    # 修改属性
  });

  # 添加新包
  myPackage = final.callPackage ../pkgs/my-package { };
}
```

Overlay 会自动被 [`overlays/default.nix`](../../overlays/default.nix) 加载。

## 分配服务端口号

### 端口分配机制

端口常量定义在 [`helpers/constants/ports.nix`](../../helpers/constants/ports.nix) 中，使用嵌套属性结构组织。

**端口范围规划**：

| 端口范围    | 用途                          |
| ----------- | ----------------------------- |
| 1-9999      | 知名服务和标准端口            |
| 10000-13999 | 自定义服务端口                |
| 30000+      | 特殊用途（如 WireGuard 转发） |

### 步骤 1：选择合适的端口

1. 查看现有端口分配，避免冲突
2. 根据服务类型选择合适的端口范围
3. 相关服务的端口尽量相邻

### 步骤 2：添加端口常量

在 [`helpers/constants/ports.nix`](../../helpers/constants/ports.nix) 的 `port` 属性集中添加：

```nix
port = {
  # ... 现有端口 ...

  # 新服务端口
  MyService = 13xxx;           # 单个端口
  MyService.API = 13xxx;       # 带子服务的端口
  MyService.UI = 13xxx;

  # 端口范围
  MyService.Start = 13xxx;
  MyService.End = 13xxx;
};
```

### 步骤 3：在模块中使用端口

```nix
{ LT, ... }:
{
  services.myService = {
    port = LT.port.MyService;
  };
}
```

`LT` 辅助对象在模块中自动可用，包含所有常量和辅助函数。

### 步骤 4：使用字符串格式端口

如果需要字符串格式的端口号，使用 `portStr`：

```nix
portStr.MyService  # 返回 "13xxx" 而非 13xxx
```
