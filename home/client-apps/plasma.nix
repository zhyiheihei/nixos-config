{ pkgs, lib, osConfig, ... }:
let
  kcminitFonts = "${pkgs.kdePackages.plasma-workspace}/bin/kcminit kcm_fonts_init";
in
{
  # X11 应用（如 wechat-uos 的 QT_AUTO_SCREEN_SCALE_FACTOR）从 xrdb 的 Xft.dpi
  # 取缩放，由 kcminit (kcm_fonts_init) 写入。登录时序竞争：plasma-kcminit 在
  # KWin 创建 wayland-0 socket 之前启动，QGuiApplication 回退 xcb，
  # krdb::xftDpi 走非 Wayland 分支读 kcmfonts forceFontDPI（默认 96），而非
  # kwinrc Xwayland.Scale×96，导致 X11 应用不缩放。实测于 ml-laptop：
  # 无 WAYLAND_DISPLAY 时 kcminit 写 96，有则写 144。
  # 修复：登录后 plasma-workspace.target 就绪（wayland socket + DISPLAY 均已
  # 就绪）时重跑一次。另加 home.activation 钩子处理中途 nixos-rebuild switch：
  # 该场景下 stylixLookAndFeel（QT_QPA_PLATFORM=minimal）会把 Xft.dpi 重置回
  # 96，且按字母序排在 reloadSystemd 之后；钩子排序在 stylix 之后，且仅有
  # 显示器可用时（会话已运行）才会实际生效。
  home.activation.zz-fix-xwayland-dpi = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -n "''${DISPLAY:-}" ] || [ -n "''${WAYLAND_DISPLAY:-}" ]; then
      ${kcminitFonts} || true
    fi
  '';

  systemd.user.services.fix-xwayland-dpi = {
    Unit = {
      Description = "Re-run kcminit fonts init to fix Xft.dpi race at login";
      After = [ "plasma-workspace.target" ];
      PartOf = [ "graphical-session.target" ];
    };

    Service = {
      Type = "oneshot";
      ExecStart = kcminitFonts;
    };

    Install = {
      WantedBy = [ "plasma-workspace.target" ];
    };
  };

  programs.okular = {
    enable = true;
    package = null;
    general = {
      mouseMode = "TextSelect";
      obeyDrm = false;
      openFileInTabs = true;
      showScrollbars = true;
      smoothScrolling = true;
      viewContinuous = true;
      zoomMode = "autoFit";
    };
    performance = {
      enableTransparencyEffects = true;
      memoryUsage = "Greedy";
    };
  };

  programs.plasma = {
    enable = true;
    immutableByDefault = true;
    overrideConfig = false;
    resetFiles = [
      # keep-sorted start
      "kglobalshortcutsrc"
      "khotkeysrc"
      "kscreenlockerrc"
      "ksmserverrc"
      "ksplashrc"
      "kwinrc"
      "kwinrulesrc"
      "okularpartrc"
      "powerdevilrc"
      # keep-sorted end
    ];

    configFile.kwinrc = {
      Compositing = {
        AllowDirectScanout.value = false;
        GLCore = true;
        LatencyPolicy = "ExtremelyLow";
        OpenGLIsUnsafe = false;
        WindowsBlockCompositing = false;
      };
      "Wayland".InputMethod = {
        shellExpand = true;
        value = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
      };
      Xwayland.Scale = osConfig.lantian.hidpi or 1;
      Windows.RollOverDesktops = true;
      "org.kde.kdecoration2".ShowToolTips = false;

      Plugins.better_blur_dxEnabled = true;
      Effect-better-blur-dx = {
        BlitMode = "WALLPAPER";
        BlurDecorations = true;
        BlurMatching = false;
        BlurMenus = true;
        BlurNonMatching = true;
        BlurStrength = 4;
        Brightness = 25;
        NoiseStrength = 0;
      };
      # Disable wallpaper scrolling on workspace switch
      Effect-slide.SlideBackground = false;
    };

    desktop = {
      icons = {
        alignment = "left";
        arrangement = "topToBottom";
        folderPreviewPopups = false;
        lockInPlace = true;
        size = 3;
        sorting = {
          descending = false;
          foldersFirst = true;
          mode = "name";
        };
      };
    };

    hotkeys.commands = {
      jamesdsp-toggle = {
        command = "jamesdsp-toggle";
        comment = "Toggle JamesDSP on/off";
        key = "Launch (8)";
      };
      terminal = {
        command = "ghostty";
        comment = "Start terminal";
        key = "Launch (2)";
      };
      terminal-python = {
        command = "ghostty -e python3";
        comment = "Start terminal with Python";
        key = "Calculator";
      };
      ulauncher-toggle = {
        command = "ulauncher-toggle";
        comment = "Toggle Ulauncher search bar";
        key = "Meta+Space";
      };
      noop = {
        command = "true";
        comment = "No Operation";
        keys = [
          "Launch (0)"
          "Favorites"
          "Launch Mail"
        ];
      };
    };

    kscreenlocker = {
      autoLock = false;
      lockOnResume = false;
      lockOnStartup = false;
    };

    kwin = {
      cornerBarrier = true;
      edgeBarrier = 100;

      effects = {
        cube.enable = false;
        desktopSwitching.animation = "slide";
        dimAdminMode.enable = true;
        dimInactive.enable = false;
        fallApart.enable = false;
        fps.enable = false;
        minimization.animation = "squash";
        shakeCursor.enable = true;
        slideBack.enable = false;
        snapHelper.enable = false;
        translucency.enable = false;
        windowOpenClose.animation = "scale";

        # Conflict with Better Blur DX
        blur.enable = false;
        wobblyWindows.enable = false;
      };

      nightLight.enable = false;

      titlebarButtons = {
        left = [
          "more-window-actions"
          "application-menu"
        ];
        right = [
          "minimize"
          "maximize"
          "close"
        ];
      };

      virtualDesktops = {
        number = 4;
        rows = 1;
      };
    };

    spectacle.shortcuts = {
      captureActiveWindow = "Meta+Print";
      captureCurrentMonitor = "Ctrl+Print";
      captureEntireDesktop = "Shift+Print";
      captureRectangularRegion = "Meta+Shift+Print";
      captureWindowUnderCursor = "Meta+Ctrl+Print";
      launch = "Print";
      launchWithoutCapturing = [ ];
      recordRegion = [
        "Meta+Shift+R"
        "Meta+R"
      ];
      recordScreen = "Meta+Alt+R";
      recordWindow = "Meta+Ctrl+R";
    };

    powerdevil = {
      AC = {
        autoSuspend.action = "nothing";
        dimDisplay.enable = false;
        powerButtonAction = "shutDown";
        powerProfile = "performance";
        turnOffDisplay.idleTimeout = "never";
        whenLaptopLidClosed = "doNothing";
      };
      battery = {
        autoSuspend.action = "nothing";
        dimDisplay.enable = false;
        powerButtonAction = "shutDown";
        powerProfile = "performance";
        turnOffDisplay.idleTimeout = "never";
        whenLaptopLidClosed = "doNothing";
      };
      lowBattery = {
        autoSuspend.action = "nothing";
        dimDisplay.enable = false;
        powerButtonAction = "shutDown";
        powerProfile = "performance";
        turnOffDisplay.idleTimeout = "never";
        whenLaptopLidClosed = "doNothing";
      };
      batteryLevels = {
        criticalAction = "shutDown";
        criticalLevel = 5;
        lowLevel = 10;
      };
    };

    session.general.askForConfirmationOnLogout = false;
    session.sessionRestore.restoreOpenApplicationsOnLogin = "startWithEmptySession";

    window-rules = [
      {
        description = "Ulauncher";
        match.window-class = {
          match-whole = false;
          type = "exact";
          value = "ulauncher";
        };
        apply = {
          above = {
            apply = "force";
            value = true;
          };
          fpplevel = {
            apply = "force";
            value = 3;
          };
          noborder = {
            apply = "force";
            value = true;
          };
          position = {
            apply = "initially";
            # FIXME: calculate based on screen size
            value = "550,120";
          };
          skippager = {
            apply = "force";
            value = true;
          };
          skipswitcher = {
            apply = "force";
            value = true;
          };
          skiptaskbar = {
            apply = "force";
            value = true;
          };
        };
      }
      {
        description = "Discord minimize by default";
        match.window-class = {
          match-whole = false;
          type = "exact";
          value = "discord";
        };
        apply = {
          ignoregeometry = {
            apply = "force";
            value = true;
          };
          minimize = {
            apply = "initially";
            value = true;
          };
        };
      }
      {
        description = "Vesktop minimize by default";
        match.window-class = {
          match-whole = false;
          type = "exact";
          value = "vesktop";
        };
        apply = {
          ignoregeometry = {
            apply = "force";
            value = true;
          };
          minimize = {
            apply = "initially";
            value = true;
          };
        };
      }
    ];

    workspace = {
      enableMiddleClickPaste = false;
      clickItemTo = "select";
      splashScreen = {
        engine = "none";
        theme = "None";
      };
    };
  };

  # Fix performance issue
  # https://github.com/NixOS/nixpkgs/issues/363068#issuecomment-5209282821
  xdg.dataFile."plasma/desktoptheme/default/translucent/colors".source =
    pkgs.kdePackages.libplasma + "/share/plasma/desktoptheme/breeze-dark/colors";
}
