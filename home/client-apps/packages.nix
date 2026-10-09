{
  pkgs,
  lib,
  LT,
  osConfig,
  config,
  inputs,
  ...
}:
let
  calibre-override-desktop = lib.hiPrio (
    pkgs.runCommand "calibre-override-desktop" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      mkdir -p $out/bin
      for F in ${pkgs.calibre}/bin/*; do
        [ -f "$F" ] || continue
        makeWrapper "$F" $out/bin/$(basename "$F") ${LT.constants.forceX11WrapperArgs}
      done

      mkdir -p $out/share/applications
      for F in ${pkgs.calibre}/share/applications/*; do
        sed "/MimeType=/d" < "$F" > $out/share/applications/$(basename "$F")
      done
    ''
  );

  jamesdsp-toggle = pkgs.writeShellScriptBin "jamesdsp-toggle" ''
    NEW_STATE=$([ $(${lib.getExe pkgs.jamesdsp} --get master_enable) = "true" ] && echo "false" || echo "true")
    ${lib.getExe pkgs.jamesdsp} --set master_enable=$NEW_STATE
    exit 0
  '';

  wine' = pkgs.wine-tkg.overrideAttrs (old: {
    prePatch =
      let
        oldPrepatch = old.prePatch or "";
      in
      (if oldPrepatch == null then "" else oldPrepatch)
      + ''
        substituteInPlace "loader/wine.inf.in" --replace-warn \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -a -r"' \
          'HKLM,%CurrentVersion%\RunServices,"winemenubuilder",2,"%11%\winemenubuilder.exe -r"'
      '';

    postFixup = ''
      ln -sf $out/bin/wine $out/bin/wine64
    '';
  });

  # uxplay 是裸 ELF，靠 GST_PLUGIN_SYSTEM_PATH_1_0 找 gstreamer 插件；会话里
  # 那串路径只有 core/base/good，缺 h264 解析/解码与 waylandsink，AirPlay 串流
  # 会直接失败。把 uxplay 自身引用的插件闭包钉进 wrapper（docs/human/hardware/ml-laptop.md）。
  uxplay-with-plugins = pkgs.symlinkJoin {
    name = "uxplay";
    paths = [ pkgs.uxplay ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/uxplay \
        --set GST_PLUGIN_SYSTEM_PATH_1_0 "${
          lib.makeSearchPath "lib/gstreamer-1.0" (
            with pkgs.gst_all_1;
            [
              gstreamer
              gst-plugins-base
              gst-plugins-good
              gst-plugins-bad
              gst-plugins-ugly
              gst-libav
            ]
          )
        }"
    '';
  };

  # 本机（Intel 核显 + GStreamer 1.28 + KWin Wayland）上 waylandsink 会把画面
  # 渲染成彩色横条纹；用同一条管线源换 1080p SMPTE 彩条本地复现：waylandsink
  # 花屏、xvimagesink 正常（上游 issue #541 同因）。显式钉死 sink，
  # autovideosink 按排名虽然也会落到 xvimagesink，但不依赖排名变化。
  mac-display = pkgs.writeShellScriptBin "mac-display" ''
    exec ${uxplay-with-plugins}/bin/uxplay -n ml-laptop -vs xvimagesink -vsync no "$@"
  '';
in
{
  imports = [ inputs.nix-index-database.homeModules.nix-index ];

  home.packages =
    with pkgs;
    (
      [
        # keep-sorted start
        (LT.wrapNetns "tnl-buyvm" deluge)
        (LT.wrapNetns "tnl-buyvm" nur-xddxdd.amule-dlp)
        (LT.wrapNetns "tnl-buyvm" qbittorrent-enhanced)
        (bambu-studio.override { withNvidiaGLWorkaround = osConfig.hardware.nvidia.enabled; })
        (hashcat.override { cudaSupport = true; })
        # error: collision between `/nix/store/2vkk2dnf693fzhlx7v2wn2kcvflgkih9-qqmusic-1.1.5/opt/LICENSE.electron.txt' and `/nix/store/zwgihw847calnxy6ff341l1qkilmn8hm-qq-3.2.2-18394/opt/LICENSE.electron.txt'
        (lib.hiPrio nur-xddxdd.qq)
        _86box-with-roms
        apache-directory-studio
        attic-client
        audacious
        bitwarden-desktop
        brotli
        bzip2
        colmena
        # ecapture
        exiftool
        feishin
        ffmpeg-full
        filezilla
        freecad
        gcdemu
        gedit
        gimp
        gopher
        handbrake
        imagemagick
        immich-cli
        jamesdsp
        jamesdsp-toggle
        jpegoptim
        kdePackages.ark
        kdePackages.isoimagewriter
        kdePackages.kdenlive
        kdePackages.kpat
        kicad
        lbzip2
        libfaketime
        linphone
        llm-agents.agentsview
        llm-agents.ccusage
        lx-music-desktop
        macchanger
        markdown-apa7th-docx
        mediainfo
        megatools
        microcom
        microfetch
        moonlight-qt
        ncdu
        nheko
        nur-xddxdd.baidunetdisk
        nur-xddxdd.baidupcs-go
        nur-xddxdd.browseros
        nur-xddxdd.cardpointers-cli
        nur-xddxdd.flashbrowser
        nur-xddxdd.google-earth-pro
        nur-xddxdd.gopherus
        nur-xddxdd.kuake-cli
        nur-xddxdd.lantianCustomized.materialgram
        nur-xddxdd.mages-bin
        nur-xddxdd.ncmdump-rs
        nur-xddxdd.qqmusic
        nur-xddxdd.runpodctl
        nur-xddxdd.space-cadet-pinball-full-tilt
        nur-xddxdd.wechat-uos-sandboxed
        nvfetcher
        optipng
        p7zip
        parallel
        parsec-bin
        payload-dumper-go
        picoforge
        piliplus
        powertop
        pwgen
        qrcp
        quasselClient
        rar
        rustdesk
        siyuan
        steam-run
        synadm
        tigervnc
        tor-browser
        ulauncher
        unar
        ventoy-full
        virt-manager
        vlc
        vopono
        wine'
        winetricks
        wpsoffice
        xca
        xdg-ninja
        yubioath-flutter
        z-library-desktop
        zoom-us
        # keep-sorted end
      ]
      ++ lib.optionals (osConfig.networking.hostName == "ml-laptop") [
        nur-xddxdd.svp_4_6
        # AirPlay 接收端：Mac 把本机当副屏用（docs/human/hardware/ml-laptop.md）。
        uxplay-with-plugins
        mac-display
      ]
    );

  programs.nix-index = {
    enable = true;
    symlinkToCacheHome = true;
    enableBashIntegration = false;
    enableZshIntegration = false;
  };
  programs.nix-index-database.comma.enable = true;

  programs.aria2.enable = true;

  programs.calibre = {
    enable = true;
    package = calibre-override-desktop;
  };

  programs.dbeaver = {
    enable = true;
    package = pkgs.dbeaver-bin;
  };

  programs.distrobox.enable = true;

  # # FIXME: https://github.com/NixOS/nixpkgs/issues/513245
  # programs.lutris = {
  #   enable = true;
  #   package = pkgs.lutris.override { extraPkgs = p: with p; [ xdelta ]; };
  # };

  programs.prismlauncher.enable = true;

  programs.zapzap.enable = true;

  services.remmina = {
    enable = true;
    addRdpMimeTypeAssoc = true;
    systemdService.enable = false;
  };

  # Tidy home directory
  nix.enable = lib.mkForce false; # nix will be provided by system config
  home.sessionVariables = {
    # keep-sorted start
    CUDA_CACHE_PATH = "${config.xdg.cacheHome}/nv";
    WINEPREFIX = "${config.xdg.dataHome}/wine";
    # keep-sorted end
  };
}
