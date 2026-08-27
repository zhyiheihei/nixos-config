# 与上游 lt-dell-wyse 逐字对齐的模块。注意：规则里的 PCI 卡路径
# （alsa_card.pci-0000_04_00.0）是 wyse 机型的，在 ml-2700 上匹配不到、
# 静默不生效；需在目标机用 `wpctl status` 找到实际 HDMI 音频卡名后替换。
{ pkgs, ... }:
{
  services.pipewire.wireplumber.configPackages = [
    (pkgs.writeTextFile {
      name = "wireplumber-disable-hdmi-audio";
      text = ''
        rule = {
          matches = {
            {
              { "device.name", "equals", "alsa_card.pci-0000_04_00.0" },
            },
          },
          apply_properties = {
            ["device.disabled"] = true,
          },
        }

        table.insert(alsa_monitor.rules,rule)
      '';
      destination = "/share/wireplumber/main.lua.d/51-disable-hdmi-audio.lua";
    })
  ];
}
