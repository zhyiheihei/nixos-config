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
        window.setTimeout(applySvgGlassToVisible, 60);
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

  const buildClock = () => {
    const host = document.querySelector(".information-widget-datetime");
    if (!host) return;

    const render = () => {
      if (host.querySelector(".hp-clock")) return;
      const now = new Date();
      const clock = document.createElement("div");
      clock.className = "hp-clock";
      const time = document.createElement("span");
      time.className = "hp-clock-time";
      time.textContent = now.toLocaleTimeString([], {
        hour: "2-digit",
        minute: "2-digit",
        hour12: false,
      });
      const date = document.createElement("span");
      date.className = "hp-clock-date";
      date.textContent = now.toLocaleDateString([], {
        year: "numeric",
        month: "long",
        day: "numeric",
        weekday: "long",
      });
      clock.append(time, date);
      host.replaceChildren(clock);
    };

    render();
    window.setInterval(render, 30000);
    const observer = new MutationObserver(() => {
      if (!host.querySelector(".hp-clock")) render();
    });
    observer.observe(host, { childList: true, subtree: true });
  };

  const SURFACE_FNS = {
    convex_squircle: (x) => Math.pow(1 - Math.pow(1 - x, 4), 0.25),
  };

  const calculateRefractionProfile = (thickness, bezel, heightFn, ior, samples) => {
    samples = samples || 128;
    const eta = 1 / ior;
    const profile = new Float64Array(samples);
    for (let i = 0; i < samples; i += 1) {
      const x = i / samples;
      const y = heightFn(x);
      const dx = x < 1 ? 0.0001 : -0.0001;
      const y2 = heightFn(x + dx);
      const deriv = (y2 - y) / dx;
      const mag = Math.sqrt(deriv * deriv + 1);
      const nx = -deriv / mag;
      const ny = -1 / mag;
      const dot = ny;
      const k = 1 - eta * eta * (1 - dot * dot);
      if (k < 0) {
        profile[i] = 0;
        continue;
      }
      const sq = Math.sqrt(k);
      const rx = -(eta * dot + sq) * nx;
      const ry = eta - (eta * dot + sq) * ny;
      profile[i] = rx * ((y * bezel + thickness) / ry);
    }
    return profile;
  };

  const generateDisplacementMap = (w, h, radius, bezelWidth, profile, maxDisp) => {
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    const image = ctx.createImageData(w, h);
    const d = image.data;
    for (let i = 0; i < d.length; i += 4) {
      d[i] = 128;
      d[i + 1] = 128;
      d[i + 2] = 0;
      d[i + 3] = 255;
    }

    const r = radius;
    const rSq = r * r;
    const r1Sq = (r + 1) * (r + 1);
    const rBSq = Math.max(r - bezelWidth, 0) * Math.max(r - bezelWidth, 0);
    const wB = w - r * 2;
    const hB = h - r * 2;
    const S = profile.length;

    for (let y1 = 0; y1 < h; y1 += 1) {
      for (let x1 = 0; x1 < w; x1 += 1) {
        const x = x1 < r ? x1 - r : x1 >= w - r ? x1 - r - wB : 0;
        const y = y1 < r ? y1 - r : y1 >= h - r ? y1 - r - hB : 0;
        const dSq = x * x + y * y;
        if (dSq > r1Sq || dSq < rBSq) continue;
        const dist = Math.sqrt(dSq);
        const fromSide = r - dist;
        const op =
          dSq < rSq ? 1 : 1 - (dist - Math.sqrt(rSq)) / (Math.sqrt(r1Sq) - Math.sqrt(rSq));
        if (op <= 0 || dist === 0) continue;
        const cos = x / dist;
        const sin = y / dist;
        const bi = Math.min(((fromSide / bezelWidth) * S) | 0, S - 1);
        const disp = profile[bi] || 0;
        const dX = (-cos * disp) / maxDisp;
        const dY = (-sin * disp) / maxDisp;
        const idx = (y1 * w + x1) * 4;
        d[idx] = (128 + dX * 127 * op + 0.5) | 0;
        d[idx + 1] = (128 + dY * 127 * op + 0.5) | 0;
      }
    }
    ctx.putImageData(image, 0, 0);
    return canvas.toDataURL();
  };

  const generateSpecularMap = (w, h, radius, bezelWidth, angle) => {
    angle = angle != null ? angle : Math.PI / 3;
    const canvas = document.createElement("canvas");
    canvas.width = w;
    canvas.height = h;
    const ctx = canvas.getContext("2d");
    const image = ctx.createImageData(w, h);
    const d = image.data;
    d.fill(0);

    const r = radius;
    const rSq = r * r;
    const r1Sq = (r + 1) * (r + 1);
    const rBSq = Math.max(r - bezelWidth, 0) * Math.max(r - bezelWidth, 0);
    const wB = w - r * 2;
    const hB = h - r * 2;
    const sv = [Math.cos(angle), Math.sin(angle)];

    for (let y1 = 0; y1 < h; y1 += 1) {
      for (let x1 = 0; x1 < w; x1 += 1) {
        const x = x1 < r ? x1 - r : x1 >= w - r ? x1 - r - wB : 0;
        const y = y1 < r ? y1 - r : y1 >= h - r ? y1 - r - hB : 0;
        const dSq = x * x + y * y;
        if (dSq > r1Sq || dSq < rBSq) continue;
        const dist = Math.sqrt(dSq);
        const fromSide = r - dist;
        const op =
          dSq < rSq ? 1 : 1 - (dist - Math.sqrt(rSq)) / (Math.sqrt(r1Sq) - Math.sqrt(rSq));
        if (op <= 0 || dist === 0) continue;
        const cos = x / dist;
        const sin = -y / dist;
        const dot = Math.abs(cos * sv[0] + sin * sv[1]);
        const edge = Math.sqrt(Math.max(0, 1 - (1 - fromSide) * (1 - fromSide)));
        const coeff = dot * edge;
        const col = (255 * coeff) | 0;
        const alpha = (col * coeff * op) | 0;
        const idx = (y1 * w + x1) * 4;
        d[idx] = col;
        d[idx + 1] = col;
        d[idx + 2] = col;
        d[idx + 3] = alpha;
      }
    }
    ctx.putImageData(image, 0, 0);
    return canvas.toDataURL();
  };

  let glassCounter = 0;

  const getGlassSvgDefs = () => {
    let svg = document.getElementById("homepage-svg-defs");
    if (svg) return svg;
    svg = document.createElementNS("http://www.w3.org/2000/svg", "svg");
    svg.id = "homepage-svg-defs";
    svg.setAttribute("width", "0");
    svg.setAttribute("height", "0");
    svg.style.position = "absolute";
    svg.style.overflow = "hidden";
    svg.setAttribute("color-interpolation-filters", "sRGB");
    const defs = document.createElementNS("http://www.w3.org/2000/svg", "defs");
    svg.appendChild(defs);
    document.body.appendChild(svg);
    return svg;
  };

  const applySvgGlass = (element, options) => {
    if (!element) return;
    const rect = element.getBoundingClientRect();
    const w = Math.round(rect.width);
    const h = Math.round(rect.height);
    if (w < 8 || h < 8) return;

    const radius = options.radius || 18;
    const bezel = Math.min(
      26,
      radius - 1,
      Math.min(w, h) / 2 - 1
    );
    if (bezel < 2) return;

    const profile = calculateRefractionProfile(
      14,
      bezel,
      SURFACE_FNS.convex_squircle,
      1.52,
      128
    );
    let maxDisp = 1;
    for (let i = 0; i < profile.length; i += 1) {
      maxDisp = Math.max(maxDisp, Math.abs(profile[i]));
    }
    const dispUrl = generateDisplacementMap(
      w,
      h,
      radius,
      bezel,
      profile,
      maxDisp
    );
    const specUrl = generateSpecularMap(
      w,
      h,
      radius,
      bezel * 2.5,
      Math.PI / 3
    );

    const svg = getGlassSvgDefs();
    const oldId = element.dataset.homepageGlassFilter;
    if (oldId) {
      const old = document.getElementById(oldId);
      if (old && old.parentNode) old.parentNode.removeChild(old);
    }

    glassCounter += 1;
    const id = "homepage-svg-glass-" + glassCounter;
    const filter = document.createElementNS("http://www.w3.org/2000/svg", "filter");
    filter.id = id;
    filter.setAttribute("x", "-20%");
    filter.setAttribute("y", "-20%");
    filter.setAttribute("width", "140%");
    filter.setAttribute("height", "140%");
    filter.innerHTML =
      '<feGaussianBlur in="SourceGraphic" stdDeviation="2" result="blurred_source" />' +
      '<feImage href="' +
      dispUrl +
      '" x="0" y="0" width="' +
      w +
      '" height="' +
      h +
      '" result="disp_map" />' +
      '<feDisplacementMap in="blurred_source" in2="disp_map" scale="' +
      maxDisp +
      '" xChannelSelector="R" yChannelSelector="G" result="displaced" />' +
      '<feColorMatrix in="displaced" type="saturate" values="4" result="displaced_sat" />' +
      '<feImage href="' +
      specUrl +
      '" x="0" y="0" width="' +
      w +
      '" height="' +
      h +
      '" result="spec_layer" />' +
      '<feComposite in="displaced_sat" in2="spec_layer" operator="in" result="spec_masked" />' +
      '<feComponentTransfer in="spec_layer" result="spec_faded"><feFuncA type="linear" slope="0.55" /></feComponentTransfer>' +
      '<feBlend in="spec_masked" in2="displaced" mode="normal" result="with_sat" />' +
      '<feBlend in="spec_faded" in2="with_sat" mode="normal" />';
    svg.querySelector("defs").appendChild(filter);

    element.dataset.homepageGlassFilter = id;
    element.classList.add("homepage-svg-glass");
    element.style.setProperty("backdrop-filter", "url(#" + id + ")", "important");
    element.style.setProperty("-webkit-backdrop-filter", "url(#" + id + ")", "important");
    element.style.setProperty(
      "background",
      options.tint || "rgba(255, 255, 255, 0.055)",
      "important"
    );
  };

  const applySvgGlassToVisible = () => {
    const targets = document.querySelectorAll(
      ".homepage-tab-panel.active .services-group, " +
        ".homepage-tab-panel.active .bookmark-group, " +
        "#information-widgets .widget-container:not(.information-widget-datetime), " +
        "#homepage-search-section, " +
        ".homepage-tabbar"
    );
    targets.forEach((element) => {
      const radius = element.classList.contains("homepage-tabbar")
        ? 14
        : element.classList.contains("services-group") ||
          element.classList.contains("bookmark-group")
        ? 20
        : 16;
      applySvgGlass(element, {
        radius: radius,
        tint: "rgba(255, 255, 255, 0.055)",
      });
    });
    document.documentElement.classList.add("svg-glass");
  };

  const initLiquid = () => {
    applySvgGlassToVisible();
    let resizeTimer = null;
    window.addEventListener("resize", () => {
      window.clearTimeout(resizeTimer);
      resizeTimer = window.setTimeout(applySvgGlassToVisible, 120);
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
    buildStatusBar();
    buildClock();
    moveSearch();
    dailyQuote();
    ensureLayout();
    const layoutObserver = new MutationObserver(ensureLayout);
    layoutObserver.observe(document.body, { childList: true, subtree: true });
  });
})();
