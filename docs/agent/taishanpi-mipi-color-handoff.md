# taishanpi 3.1 寸 MIPI 屏（LCKFB 扩展板）颜色调查状态

> 2026-09-09 第四次更新（图片审查轮）。前一个 agent 无法看 PDF 里的图，本轮
> 用视觉审查补齐了全部官方资料图页，并获得一项**方向性修正**：
> **安卓出货版补丁与 buildroot 官方补丁的 init 序列完全一致（C7=0x00 +
> MADCTL=0x00），而面板厂原厂 txt（C7=0x04+36=0x10）不是出货配置且文件内部
> 注释自相矛盾。我们的 v9 补丁默认值 == 出货版配置，在同一序列下官方 BSP 栈
> 量产正常、我们主线 6.18 栈颜色旋转——因此「面板个体固定相位偏移」不再成
> 立，根因大概率在主线 VOP2/DSI 栈与 BSP 栈的行为差异。**
> 历史轮结论（「面板物理 GRB」「K230 序列 GIP 不匹配」「EoTp 偏移」）维持排除。

## 已确认事实（勿重复劳动）

1. **init 序列已三重核对无误**：wiki 转录 == 官方 BSP dtsi（用户已下载官方
   「3.1寸大显MIPI补丁.zip」原包）== 安卓出货版补丁 == 面板厂原厂
   `st7701s 2018.9.26.txt`（含 rotate_0/rotate_180 两个变体）。我们的驱动
   逐字节复刻原厂主序列。
2. **主机侧完全正确**：fb→VOP→DW（DPI_COLOR_CODING=0x5=RGB888）、HDMI 同
   fb 输出颜色正确；DW PCKHDL 已实测加/不加 EOTP_TX（NO_EOT_PACKET）两种
   都旋转，EoTp 假设排除。BSP 5.10 的 DW 核心与主线逐函数 diff，除 no-op
   差异外等价。
3. **面板映射实测表**（disp = T(s)，s=(fbR,fbG,fbB) 为线上样本，列序
   (R,G,B)，通过 HDMI 对照的 fb 通道旋转组合实验解出）：

| C7 | MADCTL | 实测色条(红绿蓝输入→显示) | T |
| --- | --- | --- | --- |
| 0x00 | 0x00 | 绿\|蓝\|红 | (s2,s3,s1) |
| 0x00 | 0x08(BGR) | 绿\|红\|蓝 | (s2,s1,s3) |
| 0x00 | 0x10(ML) | 绿\|蓝\|红 | (s2,s3,s1)（ML 通道中性） |
| 0x04 | 0x10 | 红\|蓝\|绿（左缘有白条回绕=行相位偏移特征） | (s1,s3,s2) |
| 0x04 | 0x18 | 蓝\|红\|绿 | (s2,s3,s1) |
| 0x04 | 0x10 + 0x55=0x80 | 红\|蓝\|绿（颜色同上，0x55=0x80/0x90 非相位键） | (s1,s3,s2) |

   可达映射 {(2,3,1),(2,1,3),(1,3,2)}，**恒等 (1,2,3) 不在 C7×BGR 的像
   集里**；BGR 的效果随 C7 值改变（C7=0 时交换 G/B 列馈给，C7=4 时交换
   R/B 列馈给）——进一步证明底层是「行相位偏移」而非普通通道序。
   逆向组合补偿验证过模型：fb 组合按 (fbR=g,fbG=b,fbB=r) 写入时 MIPI
   显示完全正确（HDMI 相应反向）——补偿模型 100% 闭环。
4. **lckfb_gip（bank-3 EF 08 前导+E8 dance）无效果**：官方原厂序列本身就没
   有这两段，加了也一样旋转。
5. 运行时矩阵：lckfb_cc / vop / vcom / colmod / e5first / e8first / 55 / d1
   在既有取值域内未发现恒等映射（上一轮对 CC/E5/E8 扫过无效，本轮 55 三档
   无效）。

## 当前部署状态

- 补丁 v9（st7701-panel-lckfb-31inch.patch）：原厂主序列逐字节复刻 +
  NO_EOT_PACKET + 全套运行时旋钮（lckfb_format/madctl/colmod/vop/vcom/cc/
  c7/e5first/e8first/cd/d1/55/gip）。编译默认 = BSP dtsi 值（C7=0、MADCTL=0），
  开机即旋转态 (s2,s3,s1)。
- `lckfb_format` 只在 probe 生效（unbind/bind），其余旋钮 blank 循环生效：
  `echo 4 > /sys/class/graphics/fb0/blank; sleep 2; echo 0 > .../fb0/blank`
- 验证色条：`/tmp/bars.raw`（1920x1080 fb 左上 480x800 四色竖条，XRGB8888
  内存序 byte0=B/G/R/X）→ scp → `cat > /dev/fb0`，HDMI 为对照。

## 2026-09-09 图片审查轮新增（本轮核心产出）

### A. 出货版权威序列（两个独立官方版本互证）

- `代码补丁/胖妞手机安卓版代码补丁（默认竖屏）.zip` 与 `3.1寸大显MIPI补丁.zip`
  的 `tspi-rk3566-dsi-v10.dtsi` 中**有效（未注释）的 3.1 寸面板段落完全一致**：
  `C7=0x00`（注释 rotate 0:0x00, rotate 180:0x04）+ `36=0x00` + `3A=0x55` +
  `CC=0x38` + `55=0xB0` + D1=0x11，gamma/GIP 段与原厂 txt 相同。
- **面板厂原厂 txt（st7701s 2018.9.26.txt）的 LCD_Rotate_0() 写 C7=0x04+36=0x10，
  与出货版矛盾**；且该 txt 主序列写 C7=0x04 却注释「rotate 0: 0x00」——文件
  内部自相矛盾，**txt 不是权威，出货版 dtsi 才是**。
- 我们 v9 补丁默认 lckfb_c7=0x00、lckfb_madctl=0x00 **恰好等于出货版配置**，
  却在主线栈上旋转。同一序列官方栈正常 → 面板/序列双双排除，嫌疑集中到
  **主线 VOP2（VP1 路径）/ dw-mipi-dsi-rockchip 与 BSP 5.10 的行为差异**。
  （此前只逐函数 diff 过 DW DSI 核心，**VOP2 从未对照过 BSP**——这是最大缺口。）

### B. mod-3 相位模型（对全部 6 组实测的数学解释）

设每行 1440 子像素（480×3），实测映射可由两个独立操作完备生成：

1. **数据流 mod-3 相位偏移 -1**：面板列 p 显示发送流样本 p-2。
2. **C7 真实位 = source 镜像**（f(k)=1441-k）：镜像作用于 mod-3 只能翻转
   相位符号（-1 ↔ +1），**永远到不了 0**（1440≡0 mod 3）。

用该模型逐组验证实测表：C7=0/36=0x00 → (s2,s3,s1)✓；C7=0+BGR → (s2,s1,s3)✓；
C7=0x04+ML → (s1,s3,s2)✓；C7=0x04+BGR+ML → (s3,s1,s2)✓；0x55 三档无效✓
（55h=WRCACE 色彩增强，0x80/0x90/0xB0 仅为增强等级，与相位无关）；
逆向补偿 (fbR=g,fbG=b,fbB=r) 闭环✓。**「恒等映射不可达」由该模型严格推出，
不是实验不充分**——C7×BGR×ML×55 的任何组合都不可能修复，无需再扫旋钮。

### C. ST7701S V0.2 原版 PDF 图页勘误（手册 vs 量产芯片）

- C7 (SDIR)：V0.2 手册只定义 D1=SS（0x02，source 479→0）。但量产芯片实测
  0x04（D2）改变显示 → **真 SS 在 D2，手册标注位（D1）与量产不符**。C7=0x02
  尚未测过，但按镜像模型它要么无效要么同样翻相位，不指望它修复。
- 55h (WRCACE)：D7=CE_ON、D5-4=CEMD、D1-0=CABC_MD。0xB0=增强 High+CABC off。
- CDh (COLCTRL)：仅 LEDPWM 极性 + 低色深 MDT/EPF，与 RGB888 相位无关。
- CCh（原厂序列写 0x38）：V0.2 手册 Command2 BK0 **无此寄存器条目**（无文档）。
- **pad 表**（source 阵列）：`DMY×2, SDUM0, SDUM1, S[1..1440], SDUM2, SDUM3,
  DMY×2`，双排交错绑定（Y=184.5/309.5 交替）。SDUM0-3 是 source 端 dummy 输出。
- 面板规格书（大显伟业 D310T9362V1，22 页）：**无子像素排列图**（简略版），
  方形像素 pitch 0.084×0.084，2 data lane MIPI，6 串 LED 背光，时序指回 IC 手册。
- `寄存器地址.pdf` 是 **FocalTech 触摸芯片 App Note，与本问题无关**，从资料
  清单剔除。

### D. 修正后的下一步（按性价比重排）

1. **diff BSP VOP2 vs 主线 VOP2 的 VP1→DSI1 路径**（0 风险，最大嫌疑）。
   BSP 源码：github.com/CmST0us/tspi-linux-sdk（5.10.198）的
   `drivers/gpu/drm/rockchip/rockchip_drm_vop2.c`（+ vop2 寄存器表），对照
   主线 6.18 同名文件。重点：RK3566 VP1 的 dsp ctrl/DATA_SWAP/输出模式映射、
   win 起始、以及 `dsi-rgb666-p888.patch` 已踩过的 P666 位偏移是否在别的
   参数上重演。
2. **官方 buildroot 镜像对拍**（决定性，可确认 1 的结论）：泰山派=tspi，
   `系统镜像/buildroot` 的 update.img 就是泰山派官方镜像，可直接 maskrom 刷
   （先备份 eMMC 或接受重刷 NixOS，镜像在 git 里不丢）。官方系统+这块屏：
   颜色正常 → 主线栈问题坐实；旋转 → 屏个体（概率已很低）。
3. 若确认主线栈问题 → 找到具体寄存器/配置差异后做修复（可上游化则上游化）。
4. 软件保底（若最终判定屏个体，概率低）：a) VOP2 win.src_x+2 行移位补偿
   （真彩全内容修复，右缘 2 子像素黑线，属自造 hack 需用户拍板）；
   b) fbcon palette 补偿（仅控制台 16 色）。palette 机制本身成立。

## 历史结论修正（防止误导）

- 「面板物理 GRB 排列」：不准确。真实映射是 (s2,s3,s1) 类 3-循环相位族。
- 「K230 SDK 序列属于另一块屏」：序列差异不是根因（已排除）。
- 「fbdev XBGR 补偿」：对显示内容是 no-op，已回退。
- **「面板样本→列映射是固定的、官方所有 init 变体都改变不了它」（第三版
  主结论）：mod-3 相位模型成立，但把偏移归因于面板个体是未检验的假设——
  从未在官方 BSP 栈上跑过这块屏。出货版序列互证后，偏移更可能来自主线栈。**
- 「E0-EE 在 S 上无 GIP 文档；BK0 C7=SDIR(bit1=SS)」：前半句正确（V0.2 手册
  确无 E0-EE），后半句按图片轮勘误改为 **SS 实测在 D2**。

## 资料（全部已核实，勿再重新搜集）

- 官方补丁原包+面板厂原厂 init+安卓版完整补丁+buildroot 官方镜像（522MB
  update.img，未刷）：`/mnt/share/Work_Code/inport/7.手机综合项目/`。
  PDF→PNG 已转好放在 `/tmp/mipi-pdf/`（panel-*.png 22 页面板规格书、
  regs-*.png 37 页触摸 App Note、st7701-v02.txt 为 V0.2 手册文本层）。
- 面板厂原厂 init txt：权威性低于出货版 dtsi，仅作参考（见上）。
- ST7701S 规格书 V0.2 原版 PDF（310 页）：
  `.../数据手册/3.1寸屏幕资料/D310T9362V1 SPEC/ST7701S_SPEC_Preliminary V0.2.pdf`
  （此前用的 /tmp/st7701s-spec.txt V1.2 转录与本 PDF 章节页码不同，以 V0.2 为准）。
- BSP 内核镜像：github.com/CmST0us/tspi-linux-sdk（kernel 5.10.198）。
- 主线 st7701 序列对照：6.18 源码（本机 /nix/store 内核 tar 或在线）。
