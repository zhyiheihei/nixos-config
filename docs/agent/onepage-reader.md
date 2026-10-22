# OnePage 电纸书阅读器（壹页 / ESP32-C61）

作者仓库：`MoveCall/crosspoint-onepage`（CrossPoint Reader 的 C61 移植，MIT）。
本地维护分支：**`zhyiheihei/crosspoint-onepage`**（fork，只有 HEAD 上一个本地 fix 提交，
完整保留上游历史，`git rebase upstream/main` 可跟进）。
本文件记录 2026-10-22 把它接上 `books.zhyi.xin` 的全过程与踩坑，供以后重建/升级固件时对照。

## 硬件与固件事实（实测，不是推测）

| 项 | 实测值 | 取证方式 |
| --- | --- | --- |
| 芯片 | ESP32-C61, ROM `esp32c61-eco4-20250829` | 串口启动串 |
| Flash | 16 MB，厂家字节 `68`（Device `4018`） | `esptool flash-id` |
| PSRAM | **8 MB**，`esp_psram_is_initialized()=1`，已进分配池 | 诊断固件打印 `spiram init=1 size=8388608 heap=8388608` |
| 片内 SRAM 堆 | 156 KB（`internal total=159558`） | 同上 |
| USB | `303a:1001` USB-Serial/JTAG → `/dev/ttyACM0`，115200 | `lsusb` |

注意：`ESP.getHeapSize()` 只统计片内 RAM，会打印 159558 让人误判「PSRAM 没起来」。
判断 PSRAM 要用 `heap_caps_get_total_size(MALLOC_CAP_SPIRAM)` 或 `esp_psram_get_size()`。

设备休眠后会从 USB 消失（`/dev/ttyACM0` 不存在），刷机/抓串口前必须先唤醒保持亮屏。

## 核心故障：OPDS over HTTPS 报 `mbedtls_ssl_setup returned -0x7F00`

`-0x7F00` = `MBEDTLS_ERR_SSL_ALLOC_FAILED`。链路上各环节的排除过程：

1. 服务端没问题：`https://books.zhyi.xin/feed` 内网 443 / 外网 8443 均 200（Basic Auth `zhyi`）。
2. 设备侧 TLS 失败与域名/DNS/证书/时钟无关，是**内存**：Wi-Fi 起来后片内只剩 9.2 KB 最大连续块，
   而 TLS 握手要 ~32 KB。
3. PSRAM 是好的（8 MB 在池里），但 **mbedTLS 用不到它**：IDF 的 `esp_mem.c` 在
   `CONFIG_MBEDTLS_INTERNAL_MEM_ALLOC=y` 下走 `MALLOC_CAP_INTERNAL|MALLOC_CAP_8BIT`。
4. 改 `custom_sdkconfig` 加 `CONFIG_MBEDTLS_EXTERNAL_MEM_ALLOC=y` **无效**：arduino 的 IDF 组件库
   是预编译的，不会随 sdkconfig 重编。反汇编 `libmbedcrypto.a` 里的 `esp_mbedtls_mem_calloc`
   仍是 `0x804`（INTERNAL|8BIT），而外部分配应当是 `0x404`（SPIRAM|8BIT）。
   症状：改配置后两次构建的 `firmware.bin` 字节数完全相同。
5. 另外 pioarduino 在 hash 变化时会 `*** Reinstall Arduino framework ***`，会把手工改的
   框架模板 `sdkconfig.orig` 覆盖回去，所以手改模板也不是可持续路径。

## 采用的修法（运行期改 mbedTLS 分配器）

在 `src/main.cpp` 的 `setup()` 最前面、任何 TLS 使用之前，把 mbedTLS 的分配器指向 PSRAM：

```cpp
static void* psramCalloc(size_t n, size_t size) {
  void* p = heap_caps_calloc(n, size, MALLOC_CAP_SPIRAM | MALLOC_CAP_8BIT);
  if (p == nullptr) p = heap_caps_calloc(n, size, MALLOC_CAP_DEFAULT);
  return p;
}
...
mbedtls_platform_set_calloc_free(psramCalloc, heap_caps_free);
```

补丁与详细根因分析在固件仓 `zhyiheihei/crosspoint-onepage`（上游 `MoveCall/crosspoint-onepage`
的 fork，本地只在 HEAD 上叠一个 fix 提交，便于 `git rebase upstream/main` 跟进），
见该仓 `FORK_NOTES.md` 与 commit `fix(tls): point mbedTLS allocator at PSRAM`。
构建/刷机：`tools/onepage-firmware/build.sh <源码目录>`、`flash.sh <firmware.bin>`。
构建必须在容器里做（本机 NixOS 直接跑 PlatformIO 会撞 `/tmp` 沙箱与动态链接器问题）；
工具链缓存放 `${HOME}/.cache/pio-c61`，冷构建约 8 分钟（其中大头是下载 8 GB 工具链），增量 20 秒级。

修复验证（串口日志）：

```
[OPDS] Fetching: https://books.zhyi.xin/feed
[OPDS] Fetching: https://books.zhyi.xin/index.php/feed/languages/1/Chinese
[HTTP] Downloaded 931374 bytes      ← 三國志演義
[BookCache] Done checking metadata cache for: /Guanzhong Luo - 三國志演義.epub
```

## 设备使用要点

- U 盘式使用：机身 flash 是固件，SD 卡放书与字体，卡必须是 FAT32（SdFat）。
- **中文界面**：固件 UI 字体只有 Latin，CJK fallback 路径在 `src/CjkUiFontSystem.h` 里硬编码为
  `/fonts/LXGWWenKai-Regular/LXGWWenKai-Regular_<size>.cpfont`。缺文件则界面全是方块。
  用固件自带 `lib/EpdFont/scripts/fontconvert_sdcard.py --intervals reading,cjk` 从
  LXGW 霞鹜文楷生成（12/14/16/18 档，约 20 MB，23659 字形），再插卡开机在
  「设置 → 语言」选简体中文。
- **书库**：OPDS 服务器地址填 `https://books.zhyi.xin/feed`（不是 `/opds`：COPS 的 `/opds` 是
  dev-only 的 OPDS 2.0 JSON 入口，非 dev 构建会 PHP fatal），用户名 `zhyi` + 统一密码，
  下载落到卡根目录，命名 `作者 - 书名.epub`。
- 设备的 AI 功能（作者页面提到的实验分支）未公开：仓库只有 `main` 一个分支、release 只有
  `v0.1.0`，无法获取。
