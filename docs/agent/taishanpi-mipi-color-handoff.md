# taishanpi 3.1 寸 MIPI 屏（LCKFB 扩展板）颜色调查状态

> 2026-09-09 第三次重写。前两版结论（「面板物理 GRB」「K230 序列 GIP 不匹配」
> 「EoTp 偏移」）均已被实验逐一排除。当前证据指向：**面板样本→列映射是固定的
> 3-循环相位偏移，官方所有 init 变体都改变不了它**。探索已做满 9 轮双色输出
> 实验，剩余假设和实验路径见文末。

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

## 资料（全部已核实，勿再重新搜集）

- 官方补丁原包+面板厂原厂 init+安卓版完整补丁+buildroot 官方镜像（522MB
  update.img，未刷）：
  `/mnt/share/Work_Code/inport/7.手机综合项目/`（数据手册/代码补丁/系统镜像）
- 面板厂原厂 init（含 rotate 变体与 0x55 的 80/90/B0 候选注释）：
  `.../数据手册/3.1寸屏幕资料/D310T9362V1 SPEC/st7701s 2018.9.26.txt`
- ST7701S 规格书 V1.2（308 页）：`/tmp/st7701s-spec.txt`（临时；NXP 社区有）。
  E0-EE 在 S 上无 GIP 文档；BK0 C7=SDIR(bit1=SS)、CC/CD/55/D1 均无文档。
- BSP 内核镜像：github.com/CmST0us/tspi-linux-sdk（kernel 5.10.198）。
- 主线 st7701 序列对照：6.18 源码（本机 /nix/store 内核 tar 或在线）。

## 下一步建议（按性价比）

1. **未测旋钮**：C7=0x02（规格书 SS 位，本轮最后一测用户未回报结果）/0x06/
   其他值；lckfb_e5first/e8first 全域扫描；lckfb_format=0(loose)×C7 组合
   （loose 需 unbind/bind 重触发 probe）。
2. **行相位偏移假设的直接验证**：若 1 中某值命中恒等映射 → 硬件级修复，
   把默认值固化进补丁即可。
3. **保底方案（纯软件、控制台够用）**：fbcon 16 色调色板按 T 逆置换补偿
   ——写一个 setvtrgb/FBIOPUTCMAP 的 systemd oneshot 即可让控制台颜色全对
   （上轮 agent 的 palette 实验未确认，机制本身成立：fbcon truecolor 从
   cmap 组 pseudo-palette）。图形/照片类内容仍需应用侧补偿。
4. **终极对拍**：刷官方 buildroot update.img（RKDevTool/maskrom），看官方
   系统在这块屏上颜色是否正常——正常则差异锁定在 VOP2 主线/BSP 驱动层
   （VP1 路径），异常则本屏个体/批次异常（找立创售后换屏）。

## 历史结论修正（防止误导）

- 「面板物理 GRB 排列」：不准确。真实映射是 (s2,s3,s1) 类 3-循环相位族，
  且随 C7/BGR 在少数几个置换间跳变，不是静态子像素排列问题。
- 「K230 SDK 序列属于另一块屏」：序列确实属于不同屏，但换成官方序列后症状
  未变——序列/序列差异不是根因。
- 「fbdev XBGR 补偿」：对显示内容是 no-op（字节序差异），已回退。
