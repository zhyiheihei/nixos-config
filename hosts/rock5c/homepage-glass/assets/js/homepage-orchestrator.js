// Homepage bootstrap: tabs, status bar, clock, quote, and WebGPU liquid glass.
// This file owns DOM/configuration concerns; studio-glass.js owns rendering.
// The single source of truth for which container is live is the
// `data-glass-container` attribute; every glass element gets `data-glass`.
(() => {
  "use strict";

  const ready = (fn) => {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  };

  const TAB_ORDER = ["公开", "私有", "快捷"];
  const CONTAINER_IDS = ["layout-groups", "services", "bookmarks"];
  let resizeObserver = null;
  let resizeTarget = null;

  const tabFromName = (name) => {
    if (name.indexOf("公开") !== -1) return "公开";
    if (name.indexOf("私有") !== -1) return "私有";
    return "快捷";
  };

  const loadScript = (src, integrity) =>
    new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      if (integrity) {
        script.integrity = integrity;
        script.crossOrigin = "anonymous";
      }
      const timer = window.setTimeout(() => {
        script.remove();
        reject(new Error("timeout: " + src));
      }, 20000);
      script.onload = () => {
        window.clearTimeout(timer);
        script.remove();
        resolve();
      };
      script.onerror = () => {
        window.clearTimeout(timer);
        script.remove();
        reject(new Error("load failed: " + src));
      };
      document.head.appendChild(script);
    });

  const groupName = (group) => {
    const title =
      group.querySelector(".service-group-name") ||
      group.querySelector(".bookmark-group-name");
    return (title && title.textContent.trim()) || "";
  };

  const findContainer = () =>
    CONTAINER_IDS.map((id) => document.getElementById(id)).find(
      (element) =>
        element &&
        element.getBoundingClientRect().width > 0 &&
        getComputedStyle(element).display !== "none" &&
        getComputedStyle(element).visibility !== "hidden" &&
        element.querySelector(
          ":scope > .services-group, :scope > .bookmark-group, " +
            ".service-card, .bookmark > a"
        )
    ) || null;

  // 一趟同步：先清掉旧标记，再按当前可见容器重建 data-glass 集合，
  // 避免 React 移动节点后残留 stale 标记。
  const syncDom = () => {
    document
      .querySelectorAll("[data-glass-container], [data-glass]")
      .forEach((element) => {
        element.removeAttribute("data-glass-container");
        element.removeAttribute("data-glass");
      });
    const container = findContainer();
    if (!container) return null;
    if (resizeObserver) {
      if (resizeTarget && resizeTarget !== container) {
        resizeObserver.unobserve(resizeTarget);
      }
      if (resizeTarget !== container) {
        resizeObserver.observe(container);
        resizeTarget = container;
      }
    }
    container.setAttribute("data-glass-container", "");
    container
      .querySelectorAll(
        ".service-card, .bookmark > a"
      )
      .forEach((element) => element.setAttribute("data-glass", ""));
    document
      .querySelectorAll(
        "#information-widgets .widget-container, #homepage-search-section, .homepage-tabbar"
      )
      .forEach((element) => element.setAttribute("data-glass", ""));
    buildTabs(container);
    moveSearch();
    return container;
  };

  const moveSearch = () => {
    const search =
      document.querySelector(
        "#information-widgets-right .information-widget-search"
      ) || document.querySelector(".information-widget-search");
    const info = document.getElementById("information-widgets");
    if (!search || !info) return;

    let section = document.getElementById("homepage-search-section");
    if (!section) {
      section = document.createElement("section");
      section.id = "homepage-search-section";
      info.parentNode.insertBefore(section, info.nextSibling);
    }
    section.setAttribute("data-glass", "");
    if (search.parentElement !== section) {
      section.appendChild(search);
    }
  };

  const buildTabs = (container) => {
    if (!container) return;
    const groups = Array.from(
      container.querySelectorAll(
        ":scope > .services-group, :scope > .bookmark-group"
      )
    );
    if (groups.length === 0) return;

    groups.forEach((group) => {
      group.dataset.tabGroup = tabFromName(groupName(group));
      if (!group.id) {
        group.id =
          "homepage-tab-panel-" +
          group.dataset.tabGroup +
          "-" +
          Array.from(container.querySelectorAll(":scope > .services-group, :scope > .bookmark-group")).indexOf(group);
      }
      group.setAttribute("role", "tabpanel");
      group.setAttribute(
        "aria-labelledby",
        "homepage-tab-" + group.dataset.tabGroup
      );
    });

    let bar = document.querySelector(".homepage-tabbar");
    if (!bar) {
      bar = document.createElement("div");
      bar.className = "homepage-tabbar";
      bar.setAttribute("role", "tablist");
      bar.setAttribute("aria-label", "首页分组");
      bar.addEventListener("keydown", (event) => {
        const buttons = Array.from(bar.querySelectorAll(".homepage-tab"));
        if (buttons.length === 0) return;
        let nextIndex = buttons.findIndex((button) =>
          button.classList.contains("active")
        );
        if (event.key === "ArrowRight") {
          nextIndex = (nextIndex + 1) % buttons.length;
        } else if (event.key === "ArrowLeft") {
          nextIndex = (nextIndex - 1 + buttons.length) % buttons.length;
        } else if (event.key === "Home") {
          nextIndex = 0;
        } else if (event.key === "End") {
          nextIndex = buttons.length - 1;
        } else {
          return;
        }
        event.preventDefault();
        buttons[nextIndex].focus();
        buttons[nextIndex].click();
      });
      container.insertBefore(bar, container.firstChild);
    }
    if (bar.parentElement !== container) {
      container.insertBefore(bar, container.firstChild);
    }
    bar.setAttribute("data-glass", "");

    const tabs = [...new Set(groups.map((group) => group.dataset.tabGroup))];
    const order = TAB_ORDER.filter((name) => tabs.includes(name));
    const current = document.documentElement.dataset.homepageTab;
    const activeTab = tabs.includes(current) ? current : order[0] || "公开";
    document.documentElement.dataset.homepageTab = activeTab;
    const activeGroupCount = groups.filter(
      (group) => group.dataset.tabGroup === activeTab
    ).length;
    container.classList.toggle("homepage-single-group", activeGroupCount === 1);

    // Reconcile buttons so late group renders stay in sync.
    Array.from(bar.querySelectorAll(".homepage-tab")).forEach((button) => {
      if (!tabs.includes(button.dataset.tab)) button.remove();
    });
    order.forEach((name, index) => {
      let button = bar.querySelector('.homepage-tab[data-tab="' + name + '"]');
      const panelIds = groups
        .filter((group) => group.dataset.tabGroup === name)
        .map((group) => group.id)
        .join(" ");
      if (!button) {
        button = document.createElement("button");
        button.type = "button";
        button.className = "homepage-tab";
        button.textContent = name;
        button.dataset.tab = name;
        button.setAttribute("role", "tab");
        button.id = "homepage-tab-" + name;
        button.setAttribute("aria-selected", "false");
        button.setAttribute("aria-controls", panelIds);
        button.addEventListener("click", () => {
          document.documentElement.dataset.homepageTab = name;
          buildTabs(findContainer());
          if (window.HomepageStudioGlass) {
            window.HomepageStudioGlass.scheduleRefresh(true);
          }
        });
        bar.insertBefore(button, bar.children[index] || null);
      }
      button.id = "homepage-tab-" + name;
      button.setAttribute("aria-controls", panelIds);
      button.classList.toggle("active", name === activeTab);
      button.setAttribute("aria-selected", name === activeTab ? "true" : "false");
      button.setAttribute("tabindex", name === activeTab ? "0" : "-1");
    });
  };

  const dailyQuote = async () => {
    let quoteRetries = 0;
    const localDayKey = () => {
      const now = new Date();
      return (
        "homepage-hitokoto-" +
        now.getFullYear() +
        "-" +
        String(now.getMonth() + 1).padStart(2, "0") +
        "-" +
        String(now.getDate()).padStart(2, "0")
      );
    };

    const refreshQuote = async () => {
      const dayKey = localDayKey();
      try {
        let quote = null;
        try {
          quote = window.localStorage.getItem(dayKey);
        } catch (e) {
          quote = null;
        }

        if (!quote) {
          const controller = new AbortController();
          const timer = window.setTimeout(() => controller.abort(), 9000);
          try {
            const response = await fetch(
              "https://v1.hitokoto.cn/?encode=json&lang=cn&c=d",
              { signal: controller.signal }
            );
            if (!response.ok) throw new Error("hitokoto " + response.status);
            const data = await response.json();
            quote = data.hitokoto + (data.from ? " —— " + data.from : "");
            try {
              window.localStorage.setItem(dayKey, quote);
            } catch (e) {
              // keep quote for this visit even if storage is unavailable
            }
          } finally {
            window.clearTimeout(timer);
          }
        }
        const target =
          document.querySelector(".information-widget-greeting span") ||
          document.querySelector(".information-widget-greeting");
        if (target && quote) {
          target.textContent = quote;
          if (window.HomepageStudioGlass) {
            window.HomepageStudioGlass.scheduleRefresh(true);
          }
        }
      } catch (e) {
        // keep the original greeting text; retry a few times within the day
        if (quoteRetries < 3 && localDayKey() === dayKey) {
          quoteRetries += 1;
          window.setTimeout(refreshQuote, 300000);
          return;
        }
      }

      const now = new Date();
      const nextDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
      window.setTimeout(refreshQuote, nextDay.getTime() - now.getTime() + 5000);
    };

    refreshQuote();
  };

  const buildStatusBar = () => {
    let bar = document.getElementById("homepage-statusbar");
    if (!bar) {
      bar = document.createElement("div");
      bar.id = "homepage-statusbar";
    } else if (statusBarReady && bar.childElementCount === 0) {
      statusBarReady = false;
    }
    if (!statusBarReady) {
    const time = document.createElement("span");
    time.className = "homepage-status-time";

    const icons = document.createElement("span");
    icons.className = "homepage-status-icons";
    icons.setAttribute("aria-hidden", "true");
    const signal = document.createElement("span");
    signal.className = "homepage-status-signal";
    for (let i = 0; i < 4; i += 1) {
      const barPart = document.createElement("i");
      signal.appendChild(barPart);
    }
    const network = document.createElement("span");
    network.className = "homepage-status-network";
    network.textContent = "5G";
    const battery = document.createElement("span");
    battery.className = "homepage-status-battery";
    icons.append(signal, network, battery);
    bar.append(time, icons);

    const updateTime = () => {
      time.textContent = new Date().toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
    };
    updateTime();
    // Rebuilds only happen for an empty bar, but the old interval must not
    // keep driving a detached <span> forever.
    if (statusTimer) window.clearInterval(statusTimer);
    statusTimer = window.setInterval(updateTime, 30000);
      statusBarReady = true;
    }

    const container = document.querySelector(".container");
    if (container && bar.parentElement !== container) {
      container.insertBefore(bar, container.firstChild);
    } else if (!container && bar.parentElement !== document.body) {
      document.body.insertBefore(bar, document.body.firstChild);
    }
  };

  let statusBarReady = false;
  let statusTimer = null;

  let studioStarted = false;
  let studioLoading = false;
  let studioAttempts = 0;
  const MAX_STUDIO_ATTEMPTS = 5;

  const initStudio = async () => {
    if (studioStarted || studioLoading) return;
    if (studioAttempts >= MAX_STUDIO_ATTEMPTS) {
      window.HomepageBootstrap = {
        status: "stopped",
        attempts: studioAttempts,
        error: "max studio attempts reached",
      };
      return;
    }
    studioLoading = true;
    studioAttempts += 1;
    window.HomepageBootstrap = {
      status: "loading",
      attempts: studioAttempts,
      error: null,
    };
    try {
      await loadScript(
        "/homepage-assets/vendor/html2canvas-pro-1.5.8.min.js",
        "sha256-Vv/S7gkGXkDiEGi19tbFIzccVh/PxqBKcYbE1H5mEPM="
      );
      await loadScript("/homepage-assets/js/studio-glass.js");
    } catch (error) {
      studioLoading = false;
      window.HomepageBootstrap = {
        status: "script-failed",
        attempts: studioAttempts,
        error: error.message,
      };
      if (studioAttempts < MAX_STUDIO_ATTEMPTS) {
        window.setTimeout(initStudio, 2000 * studioAttempts);
      }
      return;
    }
    if (!window.HomepageStudioGlass) {
      studioLoading = false;
      window.HomepageBootstrap = {
        status: "missing-global",
        attempts: studioAttempts,
        error: "HomepageStudioGlass not defined",
      };
      if (studioAttempts < MAX_STUDIO_ATTEMPTS) {
        window.setTimeout(initStudio, 2000 * studioAttempts);
      }
      return;
    }
    try {
      const container = syncDom();
      const root = document.getElementById("inner_wrapper") || container;
      const ok = await window.HomepageStudioGlass.start({
        root,
        targetFn: () => Array.from(document.querySelectorAll("[data-glass]")),
      });
      if (ok) {
        studioStarted = true;
        window.HomepageBootstrap = {
          status: "running",
          attempts: studioAttempts,
          error: null,
          glassContainerCount: document.querySelectorAll("[data-glass-container]").length,
          glassCount: document.querySelectorAll("[data-glass]").length,
        };
      } else if (studioAttempts < MAX_STUDIO_ATTEMPTS) {
        window.setTimeout(initStudio, 2000 * studioAttempts);
      } else {
        window.HomepageBootstrap = {
          status: "start-failed",
          attempts: studioAttempts,
          error: "WebGPU or html2canvas unavailable",
        };
      }
    } catch (error) {
      window.HomepageBootstrap = {
        status: "start-failed",
        attempts: studioAttempts,
        error: error.message,
      };
      if (studioAttempts < MAX_STUDIO_ATTEMPTS) {
        window.setTimeout(initStudio, 2000 * studioAttempts);
      }
    } finally {
      studioLoading = false;
    }
  };

  let layoutRaf = 0;
  let layoutTimer = 0;

  const ensureLayout = () => {
    buildStatusBar();
    const container = syncDom();
    if (!container) return;
    if (window.HomepageStudioGlass) {
      window.HomepageStudioGlass.scheduleRefresh(false);
    }
    initStudio();
  };

  const scheduleEnsure = () => {
    if (layoutRaf) return;
    layoutRaf = window.requestAnimationFrame(() => {
      layoutRaf = 0;
      ensureLayout();
    });
  };

  ready(() => {
    resizeObserver = new ResizeObserver(() => {
      if (layoutTimer) window.clearTimeout(layoutTimer);
      layoutTimer = window.setTimeout(() => {
        layoutTimer = 0;
        ensureLayout();
      }, 120);
    });
    buildStatusBar();
    moveSearch();
    dailyQuote();
    ensureLayout();
    window.setTimeout(scheduleEnsure, 300);

    const layoutObserver = new MutationObserver(scheduleEnsure);
    layoutObserver.observe(document.body, {
      childList: true,
      subtree: true,
      attributes: true,
      attributeFilter: ["data-tab-group", "class"],
    });

    const onSearchInput = () => {
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.scheduleRefresh(true);
      }
    };
    document.addEventListener("input", (event) => {
      if (event.target && event.target.matches(".information-widget-search input")) {
        onSearchInput();
      }
    });

    document.addEventListener(
      "pointerover",
      (event) => {
        if (
          event.target &&
          event.target.closest &&
          event.target.closest("[data-glass]") &&
          window.HomepageStudioGlass
        ) {
          window.HomepageStudioGlass.scheduleRefresh(false);
        }
      },
      { passive: true }
    );
    const refreshAfterTransition = () => {
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.scheduleRefresh(false);
      }
    };
    document.addEventListener(
      "pointerout",
      () => window.setTimeout(refreshAfterTransition, 220),
      { passive: true }
    );
    document.addEventListener(
      "transitionend",
      (event) => {
        if (
          event.target &&
          event.target.closest &&
          event.target.closest("[data-glass]")
        ) {
          refreshAfterTransition();
        }
      },
      { passive: true }
    );

    window.setInterval(() => {
      if (!document.hidden && window.HomepageStudioGlass) {
        window.HomepageStudioGlass.scheduleRefresh(true);
        const currentStatus =
          typeof window.HomepageStudioGlass.statusText === "function"
            ? window.HomepageStudioGlass.statusText()
            : "unknown";
        if (window.HomepageBootstrap) {
          // Terminal failure states (start-failed/stopped/etc.) must not be
          // overwritten by later studio status updates, otherwise the two
          // state machines contradict each other on failure semantics.
          const terminal = ["start-failed", "stopped", "script-failed", "missing-global"];
          if (!terminal.includes(window.HomepageBootstrap.status)) {
            window.HomepageBootstrap.status = currentStatus;
            if (currentStatus === "running") {
              window.HomepageBootstrap.error = null;
            }
          }
        }
      }
    }, 30000);
  });
})();
