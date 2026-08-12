// Homepage bootstrap: tabs, status bar, clock, quote, and WebGL liquid glass.
// This file owns DOM/configuration concerns; studio-glass.js owns rendering.
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
  const tabFromName = (name) => {
    if (name.indexOf("公开") !== -1) return "公开";
    if (name.indexOf("私有") !== -1) return "私有";
    return "快捷";
  };

  const GLASS_TARGETS = [
    "#layout-groups .services-group",
    "#layout-groups .bookmark-group",
    "#services .services-group",
    "#bookmarks .bookmark-group",
    "#layout-groups .service-card",
    "#layout-groups .bookmark > a",
    "#services .service-card",
    "#bookmarks .bookmark > a",
    "#information-widgets .widget-container:not(.information-widget-datetime)",
    "#homepage-search-section",
    ".homepage-tabbar",
  ];

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
    if (search.parentElement !== section) {
      section.appendChild(search);
    }
  };

  const buildTabs = () => {
    const containers = ["layout-groups", "services", "bookmarks"]
      .map((id) => document.getElementById(id))
      .filter(Boolean);
    const groups = containers.flatMap((container) =>
      Array.from(
        container.querySelectorAll(
          ":scope > .services-group, :scope > .bookmark-group"
        )
      )
    );
    if (groups.length === 0) return;

    groups.forEach((group) => {
      group.dataset.tabGroup = tabFromName(groupName(group));
    });

    let bar = document.querySelector(".homepage-tabbar");
    const tabs = [...new Set(groups.map((group) => group.dataset.tabGroup))];
    const order = TAB_ORDER.filter((name) => tabs.includes(name));
    if (!bar) {
      bar = document.createElement("div");
      bar.className = "homepage-tabbar";
      order.forEach((name, index) => {
        const button = document.createElement("button");
        button.type = "button";
        button.className = "homepage-tab" + (index === 0 ? " active" : "");
        button.textContent = name;
        button.dataset.tab = name;
        button.addEventListener("click", () => {
          document.documentElement.dataset.homepageTab = name;
          bar.querySelectorAll(".homepage-tab").forEach((tab) => {
            tab.classList.toggle("active", tab === button);
          });
          if (window.HomepageStudioGlass) {
            window.HomepageStudioGlass.scheduleRefresh(true);
          }
        });
        bar.appendChild(button);
      });
    }

    const host = containers[0];
    if (host && bar.parentElement !== host) {
      host.insertBefore(bar, host.firstChild);
    }
    document.documentElement.dataset.homepageTab =
      document.documentElement.dataset.homepageTab || order[0] || "公开";
    bar.querySelectorAll(".homepage-tab").forEach((tab) => {
      const active = tab.dataset.tab === document.documentElement.dataset.homepageTab;
      tab.classList.toggle("active", active);
    });
  };

  const dailyQuote = async () => {
    const greeting =
      document.querySelector(".information-widget-greeting span") ||
      document.querySelector(".information-widget-greeting");
    if (!greeting) return;

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
    const apply = (text) => {
      if (greeting) greeting.textContent = text;
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
        apply(quote);
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

  const initStudio = async () => {
    if (studioStarted) return;
    studioStarted = true;
    try {
      await loadScript("/homepage-assets/vendor/html2canvas-pro-1.5.8.min.js");
      await loadScript("/homepage-assets/js/studio-glass.js");
    } catch (error) {
      studioStarted = false;
      if (studioRetries < 4) {
        studioRetries += 1;
        window.setTimeout(initStudio, 2000 * studioRetries);
      }
      return;
    }
    if (!window.HomepageStudioGlass) {
      studioStarted = false;
      return;
    }
    const targets = () =>
      Array.from(document.querySelectorAll(GLASS_TARGETS.join(", ")));
    if (!window.HomepageStudioGlass.start(targets)) {
      studioStarted = false;
      if (studioRetries < 4) {
        studioRetries += 1;
        window.setTimeout(initStudio, 2000 * studioRetries);
      }
    }
  };

  let studioStarted = false;
  let studioRetries = 0;
  let layoutRaf = 0;

  const ensureLayout = () => {
    const groups = document.querySelectorAll(
      "#layout-groups > .services-group, #layout-groups > .bookmark-group, " +
        "#services > .services-group, #bookmarks > .bookmark-group"
    );
    if (groups.length === 0) return;
    buildTabs();
    moveSearch();
    if (window.HomepageStudioGlass) {
      window.HomepageStudioGlass.scheduleRefresh(false);
    }
    initStudio();
  };

  ready(() => {
    buildStatusBar();
    moveSearch();
    dailyQuote();
    ensureLayout();
    const scheduleEnsure = () => {
      if (layoutRaf) return;
      layoutRaf = window.requestAnimationFrame(() => {
        layoutRaf = 0;
        ensureLayout();
      });
    };
    const layoutObserver = new MutationObserver(scheduleEnsure);
    layoutObserver.observe(document.body, { childList: true, subtree: true });
    window.setTimeout(scheduleEnsure, 300);
  });
})();
