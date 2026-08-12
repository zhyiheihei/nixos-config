// Homepage bootstrap: tabs, status bar, clock, quote, and WebGL liquid glass.
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

  const tabFromName = (name) => {
    if (name.indexOf("公开") !== -1) return "公开";
    if (name.indexOf("私有") !== -1) return "私有";
    return "快捷";
  };

  const loadScript = (src) =>
    new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
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
    CONTAINER_IDS.map((id) => document.getElementById(id)).find(Boolean) || null;

  const markGlass = () => {
    const container = findContainer();
    if (!container) return null;
    container.setAttribute("data-glass-container", "");
    container
      .querySelectorAll(
        ":scope > .services-group, :scope > .bookmark-group, " +
          ".service-card, .bookmark > a"
      )
      .forEach((element) => element.setAttribute("data-glass", ""));
    document
      .querySelectorAll(
        "#information-widgets .widget-container, #homepage-search-section, .homepage-tabbar"
      )
      .forEach((element) => element.setAttribute("data-glass", ""));
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

  const buildTabs = () => {
    const container = findContainer();
    if (!container) return;
    const groups = Array.from(
      container.querySelectorAll(
        ":scope > .services-group, :scope > .bookmark-group"
      )
    );
    if (groups.length === 0) return;

    groups.forEach((group) => {
      group.dataset.tabGroup = tabFromName(groupName(group));
    });

    let bar = document.querySelector(".homepage-tabbar");
    if (!bar) {
      bar = document.createElement("div");
      bar.className = "homepage-tabbar";
      bar.setAttribute("role", "tablist");
      bar.setAttribute("aria-label", "首页分组");
      container.insertBefore(bar, container.firstChild);
    }
    bar.setAttribute("data-glass", "");

    const tabs = [...new Set(groups.map((group) => group.dataset.tabGroup))];
    const order = TAB_ORDER.filter((name) => tabs.includes(name));
    const current = document.documentElement.dataset.homepageTab;
    const activeTab = tabs.includes(current) ? current : order[0] || "公开";
    document.documentElement.dataset.homepageTab = activeTab;

    // Reconcile buttons so late group renders stay in sync.
    Array.from(bar.querySelectorAll(".homepage-tab")).forEach((button) => {
      if (!tabs.includes(button.dataset.tab)) button.remove();
    });
    order.forEach((name, index) => {
      let button = bar.querySelector('.homepage-tab[data-tab="' + name + '"]');
      if (!button) {
        button = document.createElement("button");
        button.type = "button";
        button.className = "homepage-tab";
        button.textContent = name;
        button.dataset.tab = name;
        button.setAttribute("role", "tab");
        button.setAttribute("aria-selected", "false");
        button.setAttribute("aria-controls", "homepage-tab-" + name);
        button.addEventListener("click", () => {
          document.documentElement.dataset.homepageTab = name;
          if (window.HomepageStudioGlass) {
            window.HomepageStudioGlass.scheduleRefresh(true);
          }
        });
        bar.insertBefore(button, bar.children[index] || null);
      }
      button.classList.toggle("active", name === activeTab);
      button.setAttribute("aria-selected", name === activeTab ? "true" : "false");
    });
  };

  const dailyQuote = async () => {
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
      const greeting =
        document.querySelector(".information-widget-greeting span") ||
        document.querySelector(".information-widget-greeting");
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
        // keep the original greeting text when the quote API is unreachable
      }

      const now = new Date();
      const nextDay = new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1);
      window.setTimeout(refreshQuote, nextDay.getTime() - now.getTime() + 5000);
    };

    refreshQuote();
  };

  const buildStatusBar = () => {
    if (document.getElementById("homepage-statusbar")) return;

    const bar = document.createElement("div");
    bar.id = "homepage-statusbar";
    const time = document.createElement("span");
    time.className = "homepage-status-time";

    const icons = document.createElement("span");
    icons.className = "homepage-status-icons";
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

    const container = document.querySelector(".container");
    if (container) {
      container.insertBefore(bar, container.firstChild);
    } else {
      document.body.insertBefore(bar, document.body.firstChild);
    }

    const updateTime = () => {
      time.textContent = new Date().toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
    };
    updateTime();
    window.setInterval(updateTime, 30000);
  };

  let studioStarted = false;
  let studioAttempts = 0;
  const MAX_STUDIO_ATTEMPTS = 5;

  const initStudio = async () => {
    if (studioStarted) return;
    studioAttempts += 1;
    window.HomepageBootstrap = {
      status: "loading",
      attempts: studioAttempts,
      error: null,
    };
    try {
      await loadScript("/homepage-assets/vendor/html2canvas-pro-1.5.8.min.js");
      await loadScript("/homepage-assets/js/studio-glass.js");
    } catch (error) {
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
    const container = markGlass();
    const ok = window.HomepageStudioGlass.start({
      root: container,
      targetFn: () => Array.from(document.querySelectorAll("[data-glass]")),
      zIndex: 5,
    });
    if (ok) {
      studioStarted = true;
      window.HomepageBootstrap = {
        status: "running",
        attempts: studioAttempts,
        error: null,
      };
    } else if (studioAttempts < MAX_STUDIO_ATTEMPTS) {
      window.setTimeout(initStudio, 2000 * studioAttempts);
    } else {
      window.HomepageBootstrap = {
        status: "start-failed",
        attempts: studioAttempts,
        error: "WebGL2 or html2canvas unavailable",
      };
    }
  };

  let layoutRaf = 0;
  let layoutTimer = 0;

  const ensureLayout = () => {
    const container = markGlass();
    if (!container) return;
    buildTabs();
    moveSearch();
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
    buildStatusBar();
    moveSearch();
    dailyQuote();
    ensureLayout();
    window.setTimeout(scheduleEnsure, 300);

    const layoutObserver = new MutationObserver(scheduleEnsure);
    layoutObserver.observe(document.body, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ["data-tab-group", "class"],
    });

    const resizeObserver = new ResizeObserver(() => {
      if (layoutTimer) window.clearTimeout(layoutTimer);
      layoutTimer = window.setTimeout(() => {
        layoutTimer = 0;
        ensureLayout();
      }, 120);
    });
    const container = findContainer();
    if (container) resizeObserver.observe(container);

    const searchInput = () =>
      document.querySelector(".information-widget-search input");
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

    window.setInterval(() => {
      if (!document.hidden && window.HomepageStudioGlass) {
        window.HomepageStudioGlass.scheduleRefresh(true);
      }
    }, 30000);
  });
})();
