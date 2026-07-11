_: {
  xdg.configFile."conda/.condarc".text = builtins.toJSON {
    channels = [ "nodefaults" ];
    custom_channels.conda-forge = "https://mirrors.ustc.edu.cn/anaconda/cloud";
    channel_priority = "strict";
    show_channel_urls = true;
  };
}
