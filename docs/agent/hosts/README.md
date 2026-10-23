# 主机配置说明（hosts/ 的注释档案）

`hosts/` 下的 Nix 文件只写代码，不写注释。所有「为什么这样配」的背景、历史决策、踩过
的坑、环境事实都记在这里，按主机分文件：

| 主机 | 文档 |
| --- | --- |
| `chromebox` | [chromebox.md](chromebox.md) |
| `dragon-q8b` | [dragon-q8b.md](dragon-q8b.md) |
| `google` | [google.md](google.md) |
| `greencloud` | [greencloud.md](greencloud.md) |
| `greencloud-jp` | [greencloud-jp.md](greencloud-jp.md) |
| `h28k` | [h28k.md](h28k.md) |
| `hostdare` | [hostdare.md](hostdare.md) |
| `lubancat1` | [lubancat1.md](lubancat1.md) |
| `ml-2700` | [ml-2700.md](ml-2700.md) |
| `ml-builder` | [ml-builder.md](ml-builder.md) |
| `ml-laptop` | [ml-laptop.md](ml-laptop.md) |
| `opi03` | [opi03.md](opi03.md) |
| `opi5p` | [opi5p.md](opi5p.md) |
| `pve-5700u` | [pve-5700u.md](pve-5700u.md) |
| `rock5c` | [rock5c.md](rock5c.md) |
| `router` | [router.md](router.md) |
| `taishanpi` | [taishanpi.md](taishanpi.md) |
| `tencent` | [tencent.md](tencent.md) |
| `tencent-cn` | [tencent-cn.md](tencent-cn.md) |
| `volcengine` | [volcengine.md](volcengine.md) |

## 约定

- **改主机配置时，理由写进对应文档，不写进 `.nix`**。代码里只保留能让 `keep-sorted`
  这类工具识别的指令性标记（start / end 标记对）。
- **例外**：嵌在 `''...''` 字符串里的内容（nftables 规则集、nginx `extraConfig`、shell/
  Python 脚本）自带注释属于生成的配置本体，`nft list ruleset`、`systemctl cat`、运行时
  调试都能看到，因此保留。
- 跨主机通用的规则不属于这里：入口结构见
  [domain-service-layout](../domain-service-layout.md)，舰队服务链见
  [fleet-service-chain](../fleet-service-chain.md)，部署流程见
  [deployment](../deployment.md)，模块该放哪见
  [module-placement-norms](../module-placement-norms.md)。
