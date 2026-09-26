# 上游对齐基线（exam）

本仓共享路径（清单见 `tools/exam-check` 的 `SHARED_PATHS`）对齐上游
xddxdd/nixos-config 的同步点。`tools/exam-check log` 据此计算上游增量，
`tools/exam-check` 据此审计漂移；同步流程见 work-norms §3。

baseline: bdf587f4ea1ad41c6198cad0b18c827a20c4d920

| 日期       | baseline | 说明                                                                                                     |
|------------|----------|----------------------------------------------------------------------------------------------------------|
| 2026-09-05 | 185a4a15 | 初次建档，对应上游 2026-09-03 HEAD。attic/dex/nextcloud/nfs/ghostty 公共模块已还原上游原版；既有行为漂移登记于 tools/exam-check-allowlist，逐个清偿 |
| 2026-09-05 | b095b488d | 首次 SOP 实测同步：消化上游 8 提交（bambu-studio 改 nixpkgs 源、dlx 新服务模块、decluttarr 移除、waline 评审模型、auto 包更新）。packages.nix/sonarr/default.nix/ports.nix 为接管文件手动搬 patch；dlx 模块整体采纳（无主机导入，惰性）；auto 提交仅动 flake.lock/_sources，本仓自更新不跟随 |
| 2026-09-16 | 536ec582f | 消化上游 87+ 提交（b095b488d→536ec582）：DNS Bunny 脚本化 GeoDNS + record-handlers toJSON 重写（保留 fork NO_PURGE）、nginx proxyOverrideOrigin 选项、fonts 动态 chinese-fonts-overlay + 旧 Windows 字体 alias、scx bpfland、sysctl-reset、fluidsynth OS 服务、sonarr-queue-cleanup、immich cudaCapabilities、cuda-pascal overlay、pve overlay 重构（proxmox-nixos 切回 SaumonNet）、pve oom-score-protect、nginx LAN 认证 policy、journald settings 除外（nixpkgs 锁定差异）。exam-check 新增 upstream-file skip: 登记；flake.lock 全量对齐 exam 实际求值 rev（nixpkgs 跟随上游，secrets/zhyi-packages/ncps 保持 fork） |
| 2026-09-26 | bdf587f4e | 消化上游 63 提交（536ec582f→bdf587f4e）：kubo/suricata/logstash/elasticsearch/evebox 新模块链 + 56-evebox/57-mcp-libvirt overlay + nvfetcher evebox 源；mcp-libvirt-vm-use flake 输入 + mcp-servers libvirt 接线（browseros 门控改 ml-laptop）；repology.org RPZ 硬编码（3c5ff36bc）+ zones 手动搬 repology 行；uni-api HOST/PORT env + custom-listen-host 补丁随上游 03174835 同步（fix-tool-parameters 上游已修，fork 补丁删除）；zerotier netns 路由表重写 + defaultGatewayHost 常量收口到 misc.nix（defaultGatewayHostName rock5c 承接 DN42 网关特例，fdd8 ULA）；_publiclyAccessible 选项采纳；ai-coding 插件增减（pi-usage 替代 langfuse、pi-copy-message、pi-multi-pass、@fradser/pi-utils、sanitize-user-agent）+ 07-libvirt-vm 规则 + linuxdo-hub supportsDeveloperRole；dev-tools clang-analyzer→s3cmd；ports.nix 补 IPFS/Suricata；alertmanager/llama-swap/wordpress/qbittorrent 跟随上游；flake.nix nixpkgs 切 channels.nixos.org tar.zst + mcp-libvirt 输入，flake.lock 对齐上游锁 dc5d91f8（tarball；sops-nix/nixcord/home-manager 同步，secrets/zhyi-packages/ncps 保持 fork）；h28k linux_7_1 上游移除后跟进；nixpkgs 新频道移除 networkmanager-fortisslvpn/vpnc（客户端主机）与 kernel 7.1 破坏性变更以锁回退规避，上游修复后跟随；backup.nix accb56941 已被上游 a99b3f24 回滚，净变化零；dnscontrol.nix vendorHash 随锁对齐回退上游原值。exam-check 新增 upstream 子命令（工作树 vs exam/master 归一化审计）+ NORMALIZE ssh lantian@ 规则。registry：interface-prefixes bond 前缀、vhosts-lantian skip（对应 vhosts-zhyi.nix）、command-guard/kernel swappiness fork 增强 |
