# taishanpi 3.1 寸 MIPI 屏（LCKFB 扩展板）驱动状态

> 2026-09-09 审计重写。上一轮"面板物理 GRB 排列、芯片级无解"的结论**已推翻**，
> 根因与修复见下。红绿互换问题待部署新补丁后由人眼验收。

## 硬件背景

- 主板：泰山派 RK3566，内核 6.18.45（主线），配置在
  `nixos/hardware/taishanpi/default.nix` + `pkgs/taishanpi-kernel/`。
- 扩展板：LCKFB 3.1 寸（szlcsc C42388916），面板 D310T9362V1，
  480x800 竖屏，ST7701S，2 lane。
- 背光 GP7101（I2C1 0x58，自写驱动）、触摸 CST128/FT5x06（I2C1 0x38）均已跑通。

## 根因（2026-09-09 审计结论）

上一轮把 K230 SDK 的 `st7701_480x800_init` 当成本面板的厂商序列——**序列抄录
无误，但那序列属于另一块屏**。LCKFB 官方泰山派 BSP（wiki.lckfb.com「手机综合
项目」章，"3.1寸大显MIPI补丁"）给这块屏的序列是另一套：GIP 门/源极映射表
（E1/E2/E5/E8/EB/ED）、未文档化的 BK0 CC 寄存器（0x38）、gamma、电源值
（B0/B1/B2/B5）、C7(SDIR)、垂直时序全不同。GIP 表与面板 COG 走线一一对应，
用别家屏的表驱动本面板 → 源极映射错位 → **红绿通道互换**（顺带解释了当年
"白色偏灰"：VOP/VCOM/gamma 也不是本面板的值）。

上一轮的三个中间结论全部不成立：

1. "ST7701S 无 E0-EE GIP 寄存器、写入必然被忽略"：规格书（V1.2, 2017）确实
   没文档化它们（标成 SECTRL/CABC 等），但主线 6.18 驱动里 ts8550b/rg28xx/
   rg_arc/dmt028 全在写且面板正常；官方泰山派序列也写 E5/E8——这批寄存器
   实际存在且逐面板生效。
2. "loose/packed/888 全组合结果一致，传输层排除"：`lckfb_format` 只在
   probe（`mipi_dsi_attach`）生效，fb blank 循环只重跑 prepare，**那次矩阵
   测试对 format 是无效操作**。
3. fbdev XBGR8888 补偿：XBGR vs XRGB 只是字节序差异，fbcon 按 var offset
   组色后线上颜色完全一致——对显示内容是 no-op，已回退。

官方 BSP 对这块屏就是 `dsi,format = RGB888`（主线全部 ST7701 DSI 面板也是
RGB888）；COLMOD 写 0x55 不妨碍（视频模式按包类型解码）。

## 内核补丁现状（pkgs/taishanpi-kernel/，在 hosts 配置接线）

| 补丁 | 作用 | 状态 |
| --- | --- | --- |
| st7701-panel-lckfb-31inch.patch | 面板驱动 + 官方序列（逐字节复刻） | 待部署验证 |
| gp7101-backlight.patch | 背光驱动 | 工作 |
| edt-split-i2c.patch | 触摸分立 I2C 事务 + 容忍 FIRMID NACK | 工作 |
| dsi-rgb666-p888.patch | RGB666 loose 下 VOP 输出改 P888 | 仅 lckfb_format=0 回退路径用 |

## 运行时调参（0644，改后走 blank 循环生效，format 除外）

`/sys/module/panel_sitronix_st7701/parameters/`：
- `lckfb_format` 默认 2=RGB888（厂商/BSP 值）；0=RGB666 loose、1=packed。
  **只在 probe 生效**：改后必须 unbind/bind 面板驱动，blank 无效。
- `lckfb_madctl`（默认 0x00，厂商值）、`lckfb_colmod`（默认 0x55，厂商值）
- `lckfb_vop`（0x4D）、`lckfb_vcom`（0x60）、`lckfb_cc`（0x38）
- `lckfb_e5first`/`lckfb_e8first`（0x01/0x02）、`lckfb_cd`（-1 不发）

生效流程（format 除外）：
```
echo 4 > /sys/class/graphics/fb0/blank; sleep 2; echo 0 > /sys/class/graphics/fb0/blank
```

## 部署与验证

`nix run .#colmena -- apply --on taishanpi`，内核改动需重启板子。
SSH：`root@taishanpi.zhyi.xin`（ZT）或 LAN（IP 会漂，查 kea leases）。
验收：往 fb0 写彩色条纹图确认通道（XRGB8888 内存序 byte0=B/G/R/X）：
```
python3 生成 480x800 四色竖条 -> scp -> cat bars.raw > /dev/fb0
```
颜色正确后可做清理：删 dsi-rgb666-p888.patch 与 lckfb_format 开关（收敛到
上游单一 RGB888 路径）。

## 遗留

- K230 SDK 的 480x800 屏与我们的 D310T9362V1 不是同一模块（GIP/电源/
  gamma/时序全不同），以后不要拿它当这块屏的参考序列。
- ST7701S 规格书（V1.2, 2017, 308 页）在 /tmp/st7701s-spec.pdf（本地临时
  文件，NXP 社区可下载）；其中 COLMOD 只支持 16/18/24bit，BK0 C7=SDIR、
  CC/CD 未在寄存器清单中（CC 为厂商通用但未文档化的寄存器）。
