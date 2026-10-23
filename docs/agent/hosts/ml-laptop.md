# ml-laptop（主控机，Intel Core Ultra 125H + eGPU RTX 2080 Ti）

全部 nix 求值、构建（`make local`）、colmena 部署、secrets 解密都在本机执行。
`hosts/ml-laptop/*.nix` 不写注释，理由记录在本文件。

## 角色

- 主控机 + 桌面客户端。`host.nix` **不带** `nix-builder` 标签：本机不对外通告为
  集群构建机（远程派发由 `nix-distributed` 按 `nix-builder` 标签主机组生成）。
- ltnet-scripts 管线的投递端（复刻上游作者工作机角色，见下）。
- 构建拓扑与上游 `lt-hp-omen` 对齐：本机构建默认开启（`nix-distributed` 的
  machines-with-localhost 提供 localhost 兼容槽）。
- Hydra CI 已于 2026-09-17 从本机迁往 opi5p（见
  [hydra-build-chain](../hydra-build-chain.md)）；opi5p 侧的 hydra import 目前按用户
  要求停用，构建槽位策略保留。
- 主机密钥 2026-08-19 安装时生成并持久化到 `/mnt/nix/persistent/etc/ssh`；
  ZeroTier node ID 首启后 `zerotier-cli info` 采集回填；eGPU 是 RTX 2080 Ti
  22G 改装版，llama-swap 据此选模型量化档位。

## ltnet-scripts 同步管线

复刻上游私有 `ltnet-scripts` 管线的投递端：本机定时从私有仓
`zhyiheihei/ltnet-scripts`（`zones/` 主区 + ROA 下载脚本）同步，推送到 rsync 源站
`greencloud:/nix/sync-servers/ltnet-scripts/`，再随既有的 `rsync-nix-sync-servers`
（每 10 分钟）分发全舰队。greencloud 侧不跑任何拉取服务，保持
`rsync-server.nix` 的纯源站形态（与上游 Colocrossing 一致）。

生成方式对齐作者博客《How to Kill the DN42 Network》：ROA 从 dn42 wiki Bird2 页面
引用的官方端点下载，cron 自动更新（脚本在私有仓 `scripts/sync.sh`）。`sync.sh` 的
新鲜度校验用 jq 读 `metadata.generated`，缺失会让所有 ROA 端点被判过期、stayrtr
数据永久冻结（2026-09-15 巡检发现）。

## 可选模块取舍

- 导入列表与上游 `lt-hp-omen` 逐字对齐（含注释占位）。上游有、本机不用的：
  `clamav`、`homepage`、`pipewire-noise-cancelling`、`qdrant`、`leigod-accelerator`。
- 本机在作者列表之外保留：Sunshine（Moonlight 串流服务端）、ncps-client（局域网
  二进制缓存代理）、ComfyUI（作业图片管线）。
- **ComfyUI**：本地节点式图像工作流（浏览器 UI，`localhost:8188`）。作业图片管线
  只做蒙版/贴回/校验等像素级编排，生成调用 OpenRouter 云端 API（Seedream），因此
  不需要 CUDA torch，CPU 包即可，也避开 torch+cuda 源码编译的数小时构建。上游无
  对应模块。
- **llama-swap**：脱离 NVIDIA 运行时依赖（2026-10-07 用户要求），125H 的 Arc iGPU
  走 Vulkan 后端跑 embedding，模型 qwen3-embedding-4b Q8_0（4.3GB）。两个 CN 现实
  约束：① llama.cpp 0.4.x 的 HF 下载走 cpp-httplib，不认代理环境变量，`--hf-repo`
  在 CN 不可用，模型必须落盘本地用 `-m` 指定（ModelScope 直连下载，sha256
  `b60ae5ce…` 已核验）；② 代理注入因此一并移除。上游的 models 是 CUDA
  llama-server（nomic-embed-code 7B），主机级整体覆盖；回退路径是去掉
  `vulkanSupport` 并 `-ngl 0` 即纯 CPU。
- `lab`/`llama-swap`/`pi` 的本地 vhost 都走 OAuth（与上游对齐）。
- pi 的 CLIProxyAPI 插件凭据 owner 设成 `zhyi`，供 home activation 读取后写入
  `~/.pi/agent/cliproxyapi.json`（密钥不能进 nix store，只能这样落地）。

## 备份

整机 restic 备份与作者 `lt-hp-omen` 逐字对齐（路径 `lantian`→`zhyi`）；client 默认
不启用 backup（`enable` 默认 `hasTag server`），此处显式启用。

- 快照源必须是一个 btrfs subvolume。本仓标准装机布局（安装指南 §2.1）不建
  subvolume，`/nix` 挂的是默认子卷、`/nix/persistent` 是普通目录，快照
  `/nix/persistent` 会报 `Not a Btrfs subvolume`，备份从未跑通过。现在改为快照整个
  `/nix` 子卷（上游服务器主机同款默认写法；`one-file-system` 会跳过 `/nix/store`
  独立挂载点，实际传输仍只入 persistent 子目录）。
- 只备份 `persistent/home/zhyi`，剔除大目录。容器卷里 `yuzu/Backups` 等 bindfs 挂载
  的内容由 `nix-persistent` 路径快照 `/nix` 时一并覆盖。

## 桌面

- 青简输入法（fcitx5 插件 + 用户后端 server），与中州韵并存试用。
- 划词翻译 `Ctrl+Alt+E`，KDE Wayland 下经 crow 的 D-Bus 接口触发。
- HiDPI 1.6，与 KWin Wayland 的输出缩放一致，X11/Wayland 视觉统一。
- `pipewire-roc-sink` 的接收端 IP 与上游逐字对齐（不设则 roc-sink 导入为空操作）。
- home SMB 共享与作者对齐（`force user`/`valid` 改 `zhyi`）。
- sddm 跑在 X11（登录界面），plasma session 走 wayland（`kde.nix` 默认）；sddm 的
  X11 DPI、触摸板手势、waydroid、usbmuxd 都与上游对齐。
- **waydroid**：硬编码挂载 `$XDG_RUNTIME_DIR/pulse/native`，而本机 PipeWire 跑在系统
  级（`/var/run/pulse/native`），缺链接容器起不来。系统镜像持久化：根分区是 tmpfs，
  而 `waydroid.cfg` 写死的 `images_path /etc/waydroid-extra/images` 每次重启被清空，
  容器 mount `system.img` 失败、session 起不来（2026-10-08 诊断）；镜像落在
  `/nix/persistent/waydroid/images`，启动时软链回去。
- 部分单元要补 `Restart`/`RestartSec`：上游 treewide（b1383d16）的
  ensure-service-restart 断言拒绝 systemd 默认的 100ms。
- **锁屏 PIN**：在 kde（锁屏 greeter）PAM 栈里、kwallet 捕获之后与 `pam_unix` 之前
  插入 sufficient 的本地 PIN 校验——PIN 命中直接放行，未命中走原主密码流程，两种
  凭据二选一。排序用模块要求的相对偏移写法，避免 NixOS 内建 order 变动导致规则
  漂移。部署后在目标机以 root 执行 `set-local-pin` 设置/修改；未设置或哈希文件缺失
  时规则恒失败，行为与改动前完全一致。PIN 以 sha256 存于
  `/var/lib/lantian-local-pin`（root:0600，tmpfiles 创建）；在线爆破受 greeter 的
  `StartLimitBurst=5/500s` 与 kscreenlocker 输入限速约束；`sudo`/`login`/`su` 刻意不
  接入此通道。
- **Sunshine**：`optional-apps/sunshine.nix` 是公共模块，保持不动；主机级放开
  `allowed_origins` 才能让 LAN/LTNET 浏览器访问 Web UI（否则 CSRF 保护挡住配对页），
  逗号分隔是因为该设置只接受 atom。全栈固定核显（Intel）：eGPU(card0) 不驱任何
  显示器，而本版 Sunshine 的 nvenc 初始化要求编码 GPU 自带 monitor，每轮探测都
  `Couldn't find monitor [0]` 失败（约 0.4s/轮）再回落 vulkan→vaapi；显式钉死
  `encoder=vaapi` / `capture=kms` 跳过探测循环（KMS 命中核显侧 HDMI-A-1，
  `prep_cmd` 的 kscreen-doctor 也作用于它；VA-API 由
  `client-components/xorg.nix` 的 `LIBVA_DRIVER_NAME=iHD` 驱动）。`upnp=false`：本机
  在防火墙策略里永不做公网端口转发，UPnP 映射注定失败且每天刷百余条
  `Failed to map ... 501` 噪音。

## eGPU（雷电坞）

完整排障记录、根因结论与防护层级见
[docs/human/hardware/ml-laptop-egpu.md](../../human/hardware/ml-laptop-egpu.md)。

- NVIDIA 是雷电坞外接 eGPU：未连接时 nvidia 内核模块不加载，
  `nvidia-container-toolkit-cdi-generator`（公共模块 `hardware/nvidia/prime.nix` 经
  `hardware.nvidia-container-toolkit.enable` 引入）会因 NVML "Driver Not Loaded" 硬
  失败，中止 switch-to-configuration，colmena apply 报 `Child process exited with
  error code: 4`。本机加在位条件：`/proc/driver/nvidia/version` 存在（⇔ eGPU 在位，
  模块由 udev 按设备加载）才运行，否则 unit 为 skipped，不影响激活；eGPU 在位时
  行为与上游一致。热插拔接入后要立即生成 CDI spec，手动 restart 该 unit。
- `persistenced` 同理：坞不在位时 nvidia 设备文件不存在，启动必失败并打
  `start-limit-hit`，每次开机刷一条 failed 单元；加同样的在位条件。
- eGPU 实际在 `0000:04:00.0`（总线号由雷电拓扑决定，公共 `prime.nix` 按 PCIe 直连
  dGPU 硬编码 `PCI:1:0:0`）。
- RTD3 防护：关驱动内部电源管理，防 D3cold 唤醒失败（Xid 154）；TLP 运行时 PM 排除
  eGPU 全部 4 条功能 + 上游雷电桥（D3cold 唤醒失败即 Xid 154 的根因）。
- eGPU 核心频率锁 1500MHz（TB3 P-state 跳变失联的缓解）；内核是 nixpkgs 6.12 LTS
  覆写（eGPU TB3 稳定性对照）。
- 雷电授权持久化：固件不记 thunderbolt authorized 状态，重启后 `authorized=0`、PCIe
  隧道不建立、驱动不加载。boltd 用 boot ACL 记住已授权设备，重启自动重新授权；
  首次仍需手动一次：
  `boltctl authorize --policy auto bb030000-0070-7c0e-033f-e425de412825`。
- **CUDA 目标裁剪**（`cuda-capabilities.nix`，由
  `flake-modules/nixos-configurations.nix` 在注入包集时消费）：CUDA 只编译 sm_75。
  nixpkgs 默认把 CUDA 12.9 的全部目标（sm_75～sm_121a）一起编译，nvcc 的
  cicc/ptxas 在处理 fattn-mma-f16 系列模板实例时确定性 segfault（signal 11，两次
  构建在同样文件上以同样方式崩溃），llama-cpp 因此构建失败、整机部署被卡住。本机
  只需要 sm_75，裁掉其余目标即完全避开该路径，同时大幅缩短构建时间。值形式是传给
  `-DCMAKE_CUDA_ARCHITECTURES` 的裸数字，多目标用分号分隔（如 `"75;86"`）。
  注意：`nixpkgs.config.*` 对包集不生效（pkgs 由 flake 在 NixOS 模块系统外构造后
  强制注入），实际开关只在这个文件。

## 电源与散热

- AC 模式：governor `powersave`（intel_pstate active 下即 HWP 自动调频，
  `performance`/`schedutil` 都不可用）+ EPP `performance` + 平台档 `performance`
  （Linux 侧唯一有效的风扇入口）。详见 ml-laptop 硬件文档。
- 蓝牙：AX211 的蓝牙硬件已识别（hci0），启用 bluetooth 让蓝牙可用；用作者的
  `hardware.bluetooth` 写法（`services.bluetooth` 无此选项，会导致整机 eval 失败）。

## 网络

- 主网络走 NetworkManager（client 默认）；临时有线网卡与 WiFi 都由它接管。首次安装
  验收后建议在目标机用 nmcli 把 WiFi 连接配成静态 `192.168.0.55`，连接会持久化到
  `/etc/NetworkManager/system-connections`（`client.nix` 已把该目录加入
  preservation），不必把密码写进仓库。
- 挂 opi5p（家庭文件服务器）的 NFS 共享，对应作者客户端挂 `lt-home-vm:/storage`
  的做法；automount、非阻塞。
- 不在家时经 ZeroTier 访问家庭 LAN：NixOS 主机 `allowManaged=0`，controller 下发的
  managed route 不生效，只能本机显式声明；Metric 高于 WLAN（600）/有线 DHCP 直连
  路由，在家时不劫持 br-lan 直连路径。
- **`netns-bird-kms` 的用户问题**：vlmcsd 经 `netns.kms` 广播 anycast KMS 地址，
  `netns.nix`（公共模块）给每个 `enableBird` 的 netns 起
  `netns-bird-${name}`，硬设 `User/Group=bird`；但 bird 用户只在
  `server-apps/bird`（server 角色专属）里创建，client 不导入它，导致启动报
  `status=217/USER`、colmena apply 整体失败。主机级补 bird 用户/组，定义与
  `server-apps/bird` 一致。

## 安装与硬件文件

`hardware-configuration.nix` 的结构不要手改（除磁盘 UUID）：生成模板按 UEFI 两分区
布局（EFI `/boot` + Btrfs `/nix` + tmpfs `/`），Intel 平台。分区完成后把 `blkid`
现场读到的两个 UUID 分别填进 `/boot` 与 `/nix`，并在 ml-builder 上 `nix eval` 确认
后再构建闭包。SMART 磁盘健康监控对齐 exam `lt-hp-omen`（NVMe 通用）；Intel 平台
微码 + 自由固件（AX211 WiFi 固件在 linux-firmware，必须
`enableRedistributableFirmware` 才装得进去）。
