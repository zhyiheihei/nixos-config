{ pkgs, ... }:
{
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
      "khotkeysrc"
      "kglobalshortcutsrc"
      "kscreenlockerrc"
      "ksmserverrc"
      "ksplashrc"
      "kwinrulesrc"
      "okularpartrc"
      "powerdevilrc"
    ];

    configFile.kwinrc."Wayland".InputMethod = {
      shellExpand = true;
      value = "/run/current-system/sw/share/applications/fcitx5-wayland-launcher.desktop";
    };

    # 关闭全屏应用直通扫描。Wayland 下 KWin 对全屏应用启用 direct scanout
    # 时，游戏帧直接翻到独立硬件平面；而 Sunshine 的 KMS 捕获只读主平面，
    # 串流画面于是停留在残留的桌面内容上（本机屏幕看合成结果则正常）。
    # 强制 KWin 全量合成到主平面后抓取即正确。2026-08-27 于 ml-laptop
    # 经 Moonlight 实测验证。
    configFile.kwinrc.Compositing.AllowDirectScanout.value = false;

    # 触控板滚动速度降到默认的 50%。仅对 Wayland 会话生效（KWin 读取
    # kcminputrc 的 ScrollFactor）；X11 会话走 services.libinput，无此选项。
    input.touchpads = [
      {
        enable = true;
        name = "SYNA32EB:00 06CB:CEE7 Touchpad";
        vendorId = "06CB";
        productId = "CEE7";
        scrollSpeed = 0.5;
      }
    ];

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
        blur = {
          enable = true;
          noiseStrength = 5;
          strength = 15;
        };
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
        wobblyWindows.enable = true;
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
            value = "550,160";
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
