// Homepage bootstrap: tabs, status bar, clock, quote, and WebGL liquid glass.
(() => {
  const ready = (fn) => {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  };

  const TAB_ORDER = ["公开", "私有", "快捷"];
  const TAB_RULES = [
    { name: "公开", test: (name) => name.indexOf("公开") !== -1 },
    { name: "私有", test: (name) => name.indexOf("私有") !== -1 },
    { name: "快捷", test: () => true },
  ];
  const GLASS_TARGETS = [
    ".homepage-tab-panel.active .services-group, .homepage-tab-panel.active .bookmark-group",
    "#information-widgets .widget-container:not(.information-widget-datetime)",
    "#homepage-search-section",
    ".homepage-tabbar",
  ];

  const loadScript = (src) =>
    new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.onload = resolve;
      script.onerror = () => reject(new Error("load failed: " + src));
      document.head.appendChild(script);
    });

  const groupName = (group) => {
    const title =
      group.querySelector(".service-group-name") ||
      group.querySelector(".bookmark-group-name");
    return (title && title.textContent.trim()) || "";
  };

  const tabFromName = (name) => {
    const rule = TAB_RULES.find((item) => item.test(name));
    return rule ? rule.name : "快捷";
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
    if (document.querySelector(".homepage-tabbar")) return;

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

    const tabs = [...new Set(groups.map((group) => tabFromName(groupName(group))))];
    const order = TAB_ORDER.filter((name) => tabs.includes(name));
    const bar = document.createElement("div");
    bar.className = "homepage-tabbar";

    order.forEach((name, index) => {
      const button = document.createElement("button");
      button.type = "button";
      button.className = "homepage-tab" + (index === 0 ? " active" : "");
      button.textContent = name;
      button.dataset.tab = name;
      button.addEventListener("click", () => {
        const tabbar = button.closest(".homepage-tabbar") || bar;
        tabbar
          .querySelectorAll(".homepage-tab")
          .forEach((tab) => tab.classList.toggle("active", tab === button));
        document
          .querySelectorAll(".homepage-tab-panel")
          .forEach((panel) =>
            panel.classList.toggle("active", panel.dataset.tab === name)
          );
        window.setTimeout(() => {
          if (window.HomepageStudioGlass) window.HomepageStudioGlass.refresh(true);
        }, 60);
      });
      bar.appendChild(button);
    });

    const host = containers[0];

    order.forEach((name) => {
      const panel = document.createElement("div");
      panel.className =
        "homepage-tab-panel" + (name === order[0] ? " active" : "");
      panel.dataset.tab = name;
      groups
        .filter((group) => tabFromName(groupName(group)) === name)
        .forEach((group) => panel.appendChild(group));
      host.appendChild(panel);
    });

    containers.forEach((container) => {
      container.classList.add("homepage-tabs-enabled");
      if (container !== host) container.style.display = "none";
    });
    host.insertBefore(bar, host.firstChild);
  };

  const dailyQuote = async () => {
    const greeting =
      document.querySelector(".information-widget-greeting span") ||
      document.querySelector(".information-widget-greeting");
    if (!greeting) return;

    const dayKey = "homepage-hitokoto-" + new Date().toISOString().slice(0, 10);
    const apply = (text) => {
      if (greeting) greeting.textContent = text;
    };

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
        const response = await fetch(
          "https://v1.hitokoto.cn/?encode=json&lang=cn&c=d",
          { signal: controller.signal }
        );
        window.clearTimeout(timer);
        if (!response.ok) throw new Error("hitokoto " + response.status);
        const data = await response.json();
        quote = data.hitokoto + (data.from ? " —— " + data.from : "");
        try {
          window.localStorage.setItem(dayKey, quote);
        } catch (e) {
          // keep quote for this visit even if storage is unavailable
        }
      }

      apply(quote);
    } catch (e) {
      // keep the original greeting text when the quote API is unreachable
    }
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
      await loadScript(
        "/homepage-assets/vendor/html2canvas-pro-1.5.8.min.js"
      );
      await loadScript("/homepage-assets/js/studio-glass.js");
    } catch (error) {
      return;
    }
    if (!window.HomepageStudioGlass) return;
    const targets = () =>
      Array.from(
        document.querySelectorAll(
          GLASS_TARGETS.join(", ")
        )
      );
    if (!window.HomepageStudioGlass.start(targets)) {
      studioStarted = false;
      if (studioRetries < 3) {
        studioRetries += 1;
        window.setTimeout(initStudio, 2000);
      }
    }
  };

  const buildShell = () => {
    if (document.getElementById("homepage-shell")) return;
    const shell = document.createElement("div");
    shell.id = "homepage-shell";
    const inner = document.getElementById("inner_wrapper");
    const container = document.querySelector(".container");
    [
      "homepage-statusbar",
      "information-widgets",
      "homepage-search-section",
      "layout-groups",
      "services",
      "bookmarks",
    ].forEach((id) => {
      const element = document.getElementById(id);
      if (element) shell.appendChild(element);
    });
    if (container) container.style.display = "none";
    (inner || document.body).appendChild(shell);
    document.documentElement.classList.add("homepage-shell-mode");
  };

  let tabsBuilt = false;
  let studioStarted = false;
  let studioRetries = 0;
  let layoutRaf = 0;

  const ensureLayout = () => {
    const groups = document.querySelectorAll(
      ".services-group, .bookmark-group"
    );
    if (groups.length === 0) return;
    if (!tabsBuilt) {
      buildTabs();
      tabsBuilt = true;
      if (window.HomepageStudioGlass) window.HomepageStudioGlass.refresh();
    }
    buildShell();
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
  });
})();
