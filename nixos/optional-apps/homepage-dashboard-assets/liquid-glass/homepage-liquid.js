(() => {
  const ready = (fn) => {
    if (document.readyState === "loading") {
      document.addEventListener("DOMContentLoaded", fn);
    } else {
      fn();
    }
  };

  const prefersReducedMotion = () =>
    window.matchMedia("(prefers-reduced-motion: reduce)").matches;

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
    if (name.indexOf("私有") !== -1) return "私有";
    if (name.indexOf("公开") !== -1) return "公开";
    return "快捷";
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
    const order = ["公开", "私有", "快捷"].filter((name) => tabs.includes(name));
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
        requestAnimationFrame(() => {
          if (typeof Container !== "undefined") {
            Container.instances.forEach((instance) => {
              if (instance.updateSizeFromDOM) instance.updateSizeFromDOM();
            });
          }
        });
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

  const wrapGlass = (element, options) => {
    if (!element || element.dataset.homepageGlass) return null;
    if (typeof Container === "undefined") return null;

    const glass = new Container({
      borderRadius: options.borderRadius,
      type: "rounded",
      tintOpacity: options.tintOpacity,
    });
    const className = element.className;
    const id = element.id;
    glass.element.className = className + " glass-container homepage-glass";
    if (id) glass.element.id = id;

    Array.from(element.attributes).forEach((attr) => {
      if (attr.name !== "id" && attr.name !== "class") {
        glass.element.setAttribute(attr.name, attr.value);
      }
    });

    while (element.firstChild) {
      glass.element.appendChild(element.firstChild);
    }
    element.parentNode.replaceChild(glass.element, element);
    glass.element.dataset.homepageGlass = "1";
    return glass;
  };

  const initLiquid = async () => {
    if (prefersReducedMotion()) return;

    const probe = document.createElement("canvas");
    const gl2 = probe.getContext("webgl2");
    const gl = probe.getContext("webgl");
    if (!gl2 && !gl) return;

    try {
      await loadScript(
        "/homepage-assets/liquid-glass/html2canvas-pro.min.js"
      );
      await loadScript("/homepage-assets/liquid-glass/container.js");
    } catch (e) {
      return;
    }

    window.glassControls = {
      edgeIntensity: 0.022,
      rimIntensity: 0.15,
      baseIntensity: 0.012,
      edgeDistance: 0.14,
      rimDistance: 0.7,
      baseDistance: 0.1,
      cornerBoost: 0.05,
      rippleEffect: 0.02,
      blurRadius: 5.5,
    };

    requestAnimationFrame(() => {
      document
        .querySelectorAll("#information-widgets .widget-container")
        .forEach((widget) =>
          wrapGlass(widget, { borderRadius: 16, tintOpacity: 0.12 })
        );
      const search = document.getElementById("homepage-search-section");
      if (search) {
        wrapGlass(search, { borderRadius: 18, tintOpacity: 0.1 });
      }
      const tabbar = document.querySelector(".homepage-tabbar");
      if (tabbar) {
        wrapGlass(tabbar, { borderRadius: 14, tintOpacity: 0.12 });
      }
      const bindPanels = () => {
        document
          .querySelectorAll(
            "#layout-groups .services-group, #layout-groups .bookmark-group"
          )
          .forEach((panel) =>
            wrapGlass(panel, { borderRadius: 20, tintOpacity: 0.12 })
          );
      };
      const bindPointer = () => {
        document
          .querySelectorAll(
            ".homepage-glass.services-group, .homepage-glass.bookmark-group, .homepage-glass.widget-container, .homepage-glass.homepage-tabbar"
          )
          .forEach((element) => {
            if (element.dataset.homepagePointer === "1") return;
            element.dataset.homepagePointer = "1";
            element.addEventListener("pointermove", (event) => {
              const rect = element.getBoundingClientRect();
              element.style.setProperty(
                "--lx",
                event.clientX - rect.left + "px"
              );
              element.style.setProperty(
                "--ly",
                event.clientY - rect.top + "px"
              );
            });
          });
      };
      const refreshGlass = () => {
        bindPanels();
        bindPointer();
      };
      refreshGlass();
      const cardObserver = new MutationObserver(refreshGlass);
      cardObserver.observe(document.body, { childList: true, subtree: true });

      const checkReady = window.setInterval(() => {
        if (
          typeof Container !== "undefined" &&
          Container.pageSnapshot &&
          Container.instances.some((instance) => instance.webglInitialized)
        ) {
          document.documentElement.classList.add("webgl-glass");
          window.clearInterval(checkReady);
        }
      }, 250);

      window.addEventListener("resize", () => {
        if (typeof Container !== "undefined") {
          Container.instances.forEach((instance) => {
            if (instance.updateSizeFromDOM) instance.updateSizeFromDOM();
          });
        }
      });
    });
  };

  let tabsBuilt = false;
  let liquidStarted = false;

  const ensureLayout = () => {
    const groups = document.querySelectorAll(
      ".services-group, .bookmark-group"
    );
    if (groups.length === 0) return;
    if (!tabsBuilt) {
      buildTabs();
      tabsBuilt = true;
    }
    if (!liquidStarted) {
      liquidStarted = true;
      initLiquid();
    }
  };

  ready(() => {
    moveSearch();
    dailyQuote();
    ensureLayout();
    const layoutObserver = new MutationObserver(ensureLayout);
    layoutObserver.observe(document.body, { childList: true, subtree: true });
  });
})();
