// WebGPU liquid-glass renderer driver, adapted from
// iyinchao/liquid-glass-studio. All shader math lives in
// studio-glass-webgpu.js (WGSL: bg -> blur -> main); this file owns the
// page snapshot, shape tracking, capture lifecycle and render scheduling.
// WebGPU is the only backend: no WebGL2 fallback is kept.
// MIT License (c) iyinchao/liquid-glass-studio contributors; full license
// text is distributed beside this module and under /homepage-assets/vendor/.
(() => {
  "use strict";

  const MAX_SHAPES = 128;
  const BALL_RADIUS_CSS = 100;
  const SHAPE_ROUNDNESS = 5;
  const MERGE_RATE = 0.05;
  const CARD_MERGE_RATE = 0.008;
  const REF_THICKNESS = 20;
  const REF_FACTOR = 1.4;
  const REF_DISPERSION = 7;
  const REF_FRESNEL_RANGE = 30;
  const REF_FRESNEL_HARDNESS = 0.2;
  const REF_FRESNEL_FACTOR = 0.2;
  const GLARE_RANGE = 30;
  const GLARE_HARDNESS = 0.2;
  const GLARE_FACTOR = 0.9;
  const GLARE_CONVERGENCE = 0.5;
  const GLARE_OPPOSITE_FACTOR = 0.8;
  const GLARE_ANGLE = -Math.PI / 4;
  const SHADOW_EXPAND = 25;
  const SHADOW_FACTOR = 0.15;
  const SPRING_SIZE_FACTOR = 10;
  const MAX_TEXTURE_EDGE = 4096;
  // 随机图片背景 API；与 homepage.css #inner_wrapper 的
  // --homepage-bg-image 变量（初始 url）保持一致。
  const BACKGROUND_IMAGE_URL = "https://t.alcy.cc/ysz/";

  let canvas = null;
  let captureScale = 1;
  let captureToken = 0;
  let shapeArray = null;
  let radiusArray = null;
  let shapeCount = 0;
  let mouse = { x: -4000, y: -4000 };
  let mouseSpring = { x: -4000, y: -4000 };
  let mouseVelocity = { x: 0, y: 0 };
  let lastTick = performance.now();
  let lastInteraction = Date.now();
  let dpr = 1;
  let rafId = 0;
  let idleTimer = 0;
  let getTargets = null;
  let renderRunning = false;
  let scrollRaf = 0;
  let captureStart = 0;
  let startTime = performance.now();
  let canvasAttached = false;
  let origin = { x: 0, y: 0 };
  let started = false;
  let status = "idle";
  let glassState = null;
  let resizeTimer = 0;
  let shapeTimer = 0;
  let recaptureTimer = 0;
  let rootEl = null;
  let reducedMotion = false;
  let reducedMotionBound = false;
  let captureInFlight = false;
  let captureQueued = false;
  let captureCount = 0;
  let hungTimer = 0;
  let bgImage = null;
  let bgCanvas = null;
  let bgBlobUrl = null;
  let totalShapes = 0;
  let lastFrameMs = 0;
  const reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

  const getScroll = () => {
    const container = rootEl;
    if (container) {
      // 主路径：滚动发生在 #inner_wrapper 容器内部，rect 在视口中固定，
      // origin 用视口坐标即可；窗口滚动不在支持范围内。
      return { x: container.scrollLeft, y: container.scrollTop };
    }
    return {
      x: window.pageXOffset || document.documentElement.scrollLeft || 0,
      y: window.pageYOffset || document.documentElement.scrollTop || 0,
    };
  };

  const updateOrigin = () => {
    const container = rootEl;
    if (!container) {
      origin = { x: 0, y: 0 };
      return;
    }
    const rect = container.getBoundingClientRect();
    origin = { x: rect.left, y: rect.top };
  };

  const parseRadius = (element, width, height) => {
    const value = getComputedStyle(element).borderRadius;
    const first = parseFloat(value) || 0;
    let radius = first;
    if (value.indexOf("%") !== -1) {
      radius = (Math.min(width, height) * first) / 100;
    }
    return Math.min(radius, Math.min(width, height) / 2);
  };

  const refreshShapes = () => {
    const elements = getTargets ? getTargets() : [];
    const visible = elements.filter((element) => {
      const rect = element.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    });
    const scroll = getScroll();
    totalShapes = visible.length;
    shapeCount = Math.min(totalShapes, MAX_SHAPES);
    shapeArray = new Float32Array(shapeCount * 4);
    radiusArray = new Float32Array(shapeCount);
    visible.slice(0, shapeCount).forEach((element, i) => {
      const rect = element.getBoundingClientRect();
      const radius = parseRadius(element, rect.width, rect.height);
      shapeArray[i * 4] = rect.left + scroll.x;
      shapeArray[i * 4 + 1] = rect.top + scroll.y;
      shapeArray[i * 4 + 2] = rect.width;
      shapeArray[i * 4 + 3] = rect.height;
      radiusArray[i] = radius;
    });
    if (window.HomepageStudioGlass) {
      window.HomepageStudioGlass.shapeCount = shapeCount;
      window.HomepageStudioGlass.totalShapes = totalShapes;
      window.HomepageStudioGlass.truncated = totalShapes > MAX_SHAPES;
    }
  };

  // State snapshot consumed by the WebGPU backend; refreshed before every
  // render and before every setTextures.
  const updateGlassState = () => {
    if (!glassState) glassState = {};
    const scroll = getScroll();
    updateOrigin();
    glassState.scroll = [scroll.x, scroll.y];
    glassState.origin = [origin.x, origin.y];
    glassState.dpr = dpr;
    glassState.captureScale = captureScale;
    glassState.shapeCount = shapeCount;
    glassState.shapes = shapeArray;
    glassState.radii = radiusArray;
    glassState.mouseSpring = [mouseSpring.x + scroll.x, mouseSpring.y + scroll.y];
    glassState.mouseVelocity = [mouseVelocity.x, mouseVelocity.y];
    glassState.mergeRate = MERGE_RATE;
    glassState.cardMergeRate = CARD_MERGE_RATE;
    glassState.springSizeFactor = SPRING_SIZE_FACTOR;
    glassState.ballRadius = BALL_RADIUS_CSS;
    glassState.refThickness = REF_THICKNESS;
    glassState.refFactor = REF_FACTOR;
    glassState.refDispersion = REF_DISPERSION;
    glassState.refFresnelRange = REF_FRESNEL_RANGE;
    glassState.refFresnelHardness = REF_FRESNEL_HARDNESS;
    glassState.refFresnelFactor = REF_FRESNEL_FACTOR;
    glassState.glareRange = GLARE_RANGE;
    glassState.glareHardness = GLARE_HARDNESS;
    glassState.glareFactor = GLARE_FACTOR;
    glassState.glareConvergence = GLARE_CONVERGENCE;
    glassState.glareOppositeFactor = GLARE_OPPOSITE_FACTOR;
    glassState.glareAngle = GLARE_ANGLE;
    glassState.roundness = SHAPE_ROUNDNESS;
    glassState.shadowExpand = SHADOW_EXPAND;
    glassState.shadowFactor = SHADOW_FACTOR;
    glassState.shadowOffset = [0, -10];
    glassState.startTime = startTime;
  };

  // Tail of every render frame: keep animating while recently interacted,
  // otherwise pause and schedule a wake-up render after the idle window.
  const scheduleNextFrame = (scheduleNext) => {
    if (
      scheduleNext &&
      !document.hidden &&
      (!reducedMotion || Date.now() - lastInteraction < 1500)
    ) {
      if (Date.now() - lastInteraction < 2500) {
        rafId = window.requestAnimationFrame(render);
      } else {
        renderRunning = false;
        if (idleTimer) window.clearTimeout(idleTimer);
        idleTimer = window.setTimeout(() => {
          idleTimer = 0;
          if (!renderRunning) startRender();
        }, 2000);
      }
    } else {
      renderRunning = false;
    }
  };

  const render = (now, scheduleNext = true) => {
    const frameStart = performance.now();
    if (!window.HomepageGlassWebGPU || !canvasAttached) {
      renderRunning = false;
      return;
    }
    try {
      tickMouse(now);
      updateGlassState();
      window.HomepageGlassWebGPU.render();
      lastFrameMs = performance.now() - frameStart;
      scheduleNextFrame(scheduleNext);
    } catch (error) {
      // A render exception must not freeze the loop: reset renderRunning so
      // the next interaction can startRender() again, and surface the error.
      renderRunning = false;
      status = "render-error: " + error.message;
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.lastError = error.message;
      }
    }
  };

  const startRender = () => {
    if (idleTimer) {
      window.clearTimeout(idleTimer);
      idleTimer = 0;
    }
    if (!renderRunning) {
      renderRunning = true;
      rafId = window.requestAnimationFrame(render);
    }
  };

  const tickMouse = (now) => {
    if (!now) now = performance.now();
    const dt = Math.min(0.05, Math.max(0.001, (now - lastTick) / 1000));
    lastTick = now;
    const stiffness = 150;
    const damping = 0.8;
    const ax = (mouse.x - mouseSpring.x) * stiffness;
    const ay = (mouse.y - mouseSpring.y) * stiffness;
    mouseVelocity.x = (mouseVelocity.x + ax * dt) * Math.pow(damping, dt * 60);
    mouseVelocity.y = (mouseVelocity.y + ay * dt) * Math.pow(damping, dt * 60);
    const speed = Math.hypot(mouseVelocity.x, mouseVelocity.y);
    const maxSpeed = 12000;
    if (speed > maxSpeed) {
      mouseVelocity.x = (mouseVelocity.x / speed) * maxSpeed;
      mouseVelocity.y = (mouseVelocity.y / speed) * maxSpeed;
    }
    mouseSpring.x += mouseVelocity.x * dt;
    mouseSpring.y += mouseVelocity.y * dt;
  };

  // 光晕 + 网格 overlay，与 CSS #inner_wrapper 的对应背景层保持同一套图样。
  const paintGlowAndGrid = (ctx, width, height, scale = 1) => {
    const glow = (x, y, r, color) => {
      const radial = ctx.createRadialGradient(x, y, 0, x, y, r);
      radial.addColorStop(0, color);
      radial.addColorStop(1, "rgba(0,0,0,0)");
      ctx.fillStyle = radial;
      ctx.fillRect(0, 0, width, height);
    };
    glow(width * 0.12, height * 0.18, Math.max(width, height) * 0.55, "rgba(120,150,255,0.16)");
    glow(width * 0.88, height * 0.12, Math.max(width, height) * 0.5, "rgba(90,220,220,0.12)");
    glow(width * 0.7, height * 0.85, Math.max(width, height) * 0.55, "rgba(200,120,255,0.10)");
    ctx.fillStyle = "rgba(255,255,255,0.06)";
    for (let y = 0; y < height; y += 34 * scale) {
      ctx.fillRect(0, y, width, 1);
    }
    for (let x = 0; x < width; x += 34 * scale) {
      ctx.fillRect(x, 0, 1, height);
    }
    ctx.fillStyle = "rgba(255,255,255,0.02)";
    for (let y = 0; y < height; y += 8 * scale) {
      ctx.fillRect(0, y, width, 1);
    }
    for (let x = 0; x < width; x += 8 * scale) {
      ctx.fillRect(x, 0, 1, height);
    }
  };

  const paintPageBackground = (ctx, width, height, scale = 1) => {
    if (bgCanvas) {
      // 随机图片背景：cover 变换与 CSS #inner_wrapper background-size: cover
      // 完全一致（同容器尺寸、同居中），保证玻璃纹理与真实背景无 seam。
      const iw = bgCanvas.width;
      const ih = bgCanvas.height;
      const s = Math.max(width / iw, height / ih);
      const dw = iw * s;
      const dh = ih * s;
      ctx.drawImage(bgCanvas, (width - dw) / 2, (height - dh) / 2, dw, dh);
      // 暗化层与 CSS 的 rgba(8,12,22,0.42) 层一致，保证卡片可读。
      ctx.fillStyle = "rgba(8, 12, 22, 0.42)";
      ctx.fillRect(0, 0, width, height);
      paintGlowAndGrid(ctx, width, height, scale);
      return;
    }
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, "#0b1020");
    gradient.addColorStop(0.52, "#101a2e");
    gradient.addColorStop(1, "#0a0e18");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
    paintGlowAndGrid(ctx, width, height, scale);
  };

  const paintPageOverlays = (ctx, width, height) => {
    const darkTop = ctx.createLinearGradient(0, 0, 0, height);
    darkTop.addColorStop(0, "rgba(90,120,255,0.10)");
    darkTop.addColorStop(0.28, "rgba(90,120,255,0)");
    darkTop.addColorStop(1, "rgba(90,120,255,0)");
    ctx.fillStyle = darkTop;
    ctx.fillRect(0, 0, width, height);
    const darkBottom = ctx.createLinearGradient(0, 0, 0, height);
    darkBottom.addColorStop(0, "rgba(5,8,14,0)");
    darkBottom.addColorStop(0.86, "rgba(5,8,14,0.52)");
    darkBottom.addColorStop(1, "rgba(5,8,14,0.52)");
    ctx.fillStyle = darkBottom;
    ctx.fillRect(0, 0, width, height);
  };

  const createPlaceholderTextures = () => {
    const container = rootEl;
    const rootWidth = container ? container.scrollWidth : window.innerWidth;
    const rootHeight = container ? container.scrollHeight : window.innerHeight;
    const maxEdge = MAX_TEXTURE_EDGE;
    const scale = Math.min(1, maxEdge / rootWidth, maxEdge / rootHeight);
    const width = Math.max(2, Math.round(rootWidth * scale));
    const height = Math.max(2, Math.round(rootHeight * scale));
    const placeholder = document.createElement("canvas");
    placeholder.width = width;
    placeholder.height = height;
    const pctx = placeholder.getContext("2d");
    paintPageBackground(pctx, width, height, scale);
    paintPageOverlays(pctx, width, height);
    captureScale = scale;

    if (window.HomepageGlassWebGPU) {
      updateGlassState();
      window.HomepageGlassWebGPU.setTextures(placeholder);
    }
    if (window.HomepageStudioGlass) {
      window.HomepageStudioGlass.bgTextureHeight = height;
      window.HomepageStudioGlass.captureMs = 0;
    }
  };

  const captureBackground = () => {
    const container = rootEl;
    const root = container || document.body;
    const token = ++captureToken;
    const rootWidth = container ? container.scrollWidth : window.innerWidth;
    const rootHeight = container ? container.scrollHeight : window.innerHeight;
    const maxEdge = MAX_TEXTURE_EDGE;
    const scale = Math.min(dpr, 2, maxEdge / rootWidth, maxEdge / rootHeight);
    captureStart = performance.now();
    if (window.HomepageStudioGlass) {
      window.HomepageStudioGlass.captureStage = "html2canvas";
      window.HomepageStudioGlass.captureStart = captureStart;
    }
    return window.html2canvas(root, {
      scale,
      width: rootWidth,
      height: rootHeight,
      scrollX: 0,
      scrollY: 0,
      onclone: (doc) => {
        const inner = doc.getElementById("inner_wrapper");
        if (inner) {
          inner.style.height = "auto";
          inner.style.maxHeight = "none";
          inner.style.overflow = "visible";
        }
      },
      useCORS: true,
      allowTaint: false,
      backgroundColor: null,
      logging: false,
    }).then((snapshot) => {
      // false signals the capture was superseded (hang timer or a newer
      // capture); runCapture must not update state in that case.
      if (token !== captureToken) return false;
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.captureStage = "composite";
      }
      const out = document.createElement("canvas");
      out.width = snapshot.width;
      out.height = snapshot.height;
      const ctx = out.getContext("2d");
      const bgLayer = document.createElement("canvas");
      bgLayer.width = out.width;
      bgLayer.height = out.height;
      paintPageBackground(
        bgLayer.getContext("2d"),
        out.width,
        out.height,
        out.width / rootWidth
      );
      ctx.drawImage(bgLayer, 0, 0);
      ctx.filter = "saturate(1.22) contrast(1.04) brightness(0.96)";
      ctx.drawImage(bgLayer, 0, 0);
      ctx.filter = "none";
      ctx.drawImage(snapshot, 0, 0);
      paintPageOverlays(ctx, out.width, out.height);

      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.captureStage = "upload";
      }
      if (window.HomepageGlassWebGPU) {
        updateGlassState();
        // The GPU blur pass (hblur/vblur) derives the blurred layer from the
        // same bg texture, so the CPU two-pass blur is not needed here.
        window.HomepageGlassWebGPU.setTextures(out);
      }
      captureScale = out.width / rootWidth;
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.captureStage = "done";
      }
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.bgTextureHeight = out.height;
        window.HomepageStudioGlass.captureMs = performance.now() - captureStart;
        window.HomepageStudioGlass.captureScale = captureScale;
      }
      return true;
    });
  };

  const runCapture = () => {
    if (captureInFlight) {
      captureQueued = true;
      return Promise.resolve();
    }
    captureInFlight = true;
    const armHungTimer = () => {
      if (hungTimer) window.clearTimeout(hungTimer);
      hungTimer = window.setTimeout(() => {
        captureToken += 1;
        captureInFlight = false;
        captureQueued = false;
        status = "capture-failed";
        if (window.HomepageStudioGlass) {
          window.HomepageStudioGlass.captureStage = "failed";
          window.HomepageStudioGlass.lastError = "capture hung";
        }
      }, 90000);
      return hungTimer;
    };
    // Track our own watchdog id: hungTimer is module-global and a newer
    // capture may re-arm it, so a superseded attempt must never clear it.
    let myTimer = armHungTimer();
    const attempt = async (left) => {
      const baseToken = captureToken;
      try {
        const ok = await captureBackground();
        if (ok === false) {
          // Superseded by the hang timer (or a newer capture): it owns the
          // watchdog now; do not clear it and do not touch state.
          return "superseded";
        }
        if (hungTimer === myTimer) window.clearTimeout(hungTimer);
        captureCount += 1;
        status = "running";
        if (window.HomepageStudioGlass) {
          window.HomepageStudioGlass.lastError = null;
          window.HomepageStudioGlass.captureStage = "done";
        }
        return "done";
      } catch (error) {
        if (baseToken !== captureToken - 1) {
          // This attempt's capture was invalidated (hang timer fired or a
          // newer capture started); its failure is stale, so neither update
          // state, retry, nor clear the (possibly newer) watchdog.
          return "superseded";
        }
        if (hungTimer === myTimer) window.clearTimeout(hungTimer);
        if (window.HomepageStudioGlass) {
          window.HomepageStudioGlass.captureStage = "failed";
          window.HomepageStudioGlass.lastError = error.message;
        }
        if (left > 0) {
          await new Promise((resolve) =>
            window.setTimeout(resolve, 2000 * (3 - left + 1))
          );
          // Re-arm the 90s watchdog for the retry; without it a hung retry
          // would leave captureInFlight set forever and stall the chain.
          myTimer = armHungTimer();
          return attempt(left - 1);
        }
        console.warn("studio glass capture failed", error);
        status = "capture-failed";
        return "failed";
      }
    };
    return attempt(3).then((result) => {
        if (result === "superseded") return;
        captureInFlight = false;
        if (captureQueued) {
          captureQueued = false;
          return runCapture();
        }
      });
  };

  const scheduleRefresh = (recapture) => {
    // Nothing to refresh before start(): shape/hover/30s recapture must not
    // run html2canvas while the backend is unavailable (start failed) or not
    // yet initialized, otherwise every interaction pays for a discarded
    // full-page capture.
    if (!started) return;
    if (recapture) {
      if (recaptureTimer) window.clearTimeout(recaptureTimer);
      recaptureTimer = window.setTimeout(() => {
        recaptureTimer = 0;
        if (getTargets) refreshShapes();
        if (window.HomepageGlassWebGPU) {
          runCapture().then(() => startRender());
        }
      }, 180);
    } else {
      if (shapeTimer) window.clearTimeout(shapeTimer);
      shapeTimer = window.setTimeout(() => {
        shapeTimer = 0;
        if (getTargets) refreshShapes();
        startRender();
      }, 0);
    }
  };

  const makeCanvas = () => {
    const c = document.createElement("canvas");
    c.className = "studio-glass-canvas";
    c.setAttribute("aria-hidden", "true");
    c.style.cssText = "position:fixed;inset:0;pointer-events:none;";
    return c;
  };

  const loadScript = (src) =>
    new Promise((resolve, reject) => {
      const script = document.createElement("script");
      script.src = src;
      script.onload = () => {
        script.remove();
        resolve();
      };
      script.onerror = () => {
        script.remove();
        reject(new Error("load failed: " + src));
      };
      document.head.appendChild(script);
    });

  // Canvas/pointer/scroll/resize/visibility events shared with the WebGPU
  // backend module.
  const attachSharedListeners = () => {
    const onPointer = (event) => {
      if (idleTimer) {
        window.clearTimeout(idleTimer);
        idleTimer = 0;
      }
      mouse.x = event.clientX;
      mouse.y = event.clientY;
      lastTick = performance.now();
      lastInteraction = Date.now();
      startRender();
    };
    window.addEventListener("pointermove", onPointer, { passive: true });
    window.addEventListener("pointerdown", onPointer, { passive: true });
    window.addEventListener("pointercancel", () => {}, { passive: true });
    document.addEventListener(
      "scroll",
      () => {
        if (scrollRaf) return;
        scrollRaf = window.requestAnimationFrame(() => {
          scrollRaf = 0;
          if (idleTimer) {
            window.clearTimeout(idleTimer);
            idleTimer = 0;
          }
          lastInteraction = Date.now();
          startRender();
        });
      },
      { capture: true, passive: true }
    );
    window.addEventListener(
      "resize",
      () => {
        if (resizeTimer) window.clearTimeout(resizeTimer);
        resizeTimer = window.setTimeout(() => {
          resizeTimer = 0;
          if (idleTimer) {
            window.clearTimeout(idleTimer);
            idleTimer = 0;
          }
          dpr = window.devicePixelRatio || 1;
          lastInteraction = Date.now();
          refreshShapes();
          scheduleRefresh(true);
        }, 220);
      },
      { passive: true }
    );
    document.addEventListener("visibilitychange", () => {
      if (document.hidden) {
        renderRunning = false;
      } else {
        if (idleTimer) {
          window.clearTimeout(idleTimer);
          idleTimer = 0;
        }
        lastInteraction = Date.now();
        startRender();
      }
    });
  };

  // 预加载随机图片背景（https://t.alcy.cc/ysz/）。加载成功后缩放到统一
  // 尺寸，并通过 canvas.toBlob 生成 blob URL 注入 CSS 变量——保证页面
  // 背景与玻璃纹理严格同一张图（随机 API 每次请求可能返回不同图，直接
  // 用同一 URL 的两次请求会不一致）。
  const preloadBackground = () => {
    if (bgImage) return;
    const img = new Image();
    img.crossOrigin = "anonymous";
    img.onload = () => {
      const maxEdge = 2560;
      const s = Math.min(
        1,
        maxEdge / Math.max(img.naturalWidth, img.naturalHeight)
      );
      const c = document.createElement("canvas");
      c.width = Math.max(2, Math.round(img.naturalWidth * s));
      c.height = Math.max(2, Math.round(img.naturalHeight * s));
      c.getContext("2d").drawImage(img, 0, 0, c.width, c.height);
      bgImage = img;
      bgCanvas = c;
      c.toBlob((blob) => {
        if (!blob) return;
        if (bgBlobUrl) URL.revokeObjectURL(bgBlobUrl);
        bgBlobUrl = URL.createObjectURL(blob);
        const inner = rootEl || document.getElementById("inner_wrapper");
        if (inner) {
          inner.style.setProperty(
            "--homepage-bg-image",
            'url("' + bgBlobUrl + '")'
          );
        }
        scheduleRefresh(true);
      }, "image/webp", 0.88);
    };
    img.onerror = () => {
      bgImage = null;
      bgCanvas = null;
    };
    img.src = BACKGROUND_IMAGE_URL;
  };

  const attachDeviceLostHandler = () => {
    const wgpu = window.HomepageGlassWebGPU;
    if (!wgpu || !wgpu.device || !wgpu.device.lost) return;
    wgpu.device.lost.then((info) => {
      if (rafId) window.cancelAnimationFrame(rafId);
      renderRunning = false;
      status =
        "webgpu-device-lost" + (info && info.message ? ": " + info.message : "");
    });
  };

  const start = async (options) => {
    const config =
      typeof options === "function" ? { targetFn: options } : options || {};
    getTargets = config.targetFn || null;
    rootEl = config.root || document.getElementById("inner_wrapper") || null;
    reducedMotion = reducedMotionQuery.matches;
    if (!reducedMotionBound) {
      reducedMotionBound = true;
      const onReducedMotionChange = () => {
        reducedMotion = reducedMotionQuery.matches;
        if (reducedMotion) {
          renderRunning = false;
        } else {
          startRender();
        }
      };
      if (!reducedMotionQuery.addEventListener) {
        reducedMotionQuery.addListener(onReducedMotionChange);
      } else {
        reducedMotionQuery.addEventListener("change", onReducedMotionChange);
      }
    }
    if (started) return true;
    if (typeof window.html2canvas !== "function" || !navigator.gpu) {
      status = "unavailable";
      return false;
    }
    try {
      dpr = window.devicePixelRatio || 1;
      refreshShapes();
      preloadBackground();
      canvas = makeCanvas();
      let gpuReady = false;
      try {
        await loadScript("/homepage-assets/js/studio-glass-webgpu.js");
        if (window.HomepageGlassWebGPU) {
          glassState = {};
          gpuReady = await window.HomepageGlassWebGPU.init(canvas, glassState);
        }
      } catch (error) {
        gpuReady = false;
      }
      if (!gpuReady) {
        status = "webgpu-unavailable";
        return false;
      }
      createPlaceholderTextures();
      if (!canvasAttached) {
        canvasAttached = true;
        document.body.appendChild(canvas);
        attachSharedListeners();
        attachDeviceLostHandler();
      }
      startRender();
      runCapture().then(() => startRender());
      started = true;
      status = "running";
      return true;
    } catch (error) {
      if (canvas && canvas.parentNode) canvas.parentNode.removeChild(canvas);
      canvasAttached = false;
      status = "start-failed: " + error.message;
      console.error("studio glass failed", error);
      return false;
    }
  };

  window.HomepageStudioGlass = {
    start,
    scheduleRefresh,
    debugShapes: () => ({
      count: shapeCount,
      shapes: shapeArray
        ? Array.from(shapeArray).slice(0, Math.min(shapeCount, 24) * 4)
        : null,
      radii: radiusArray
        ? Array.from(radiusArray).slice(0, Math.min(shapeCount, 24))
        : null,
      total: totalShapes,
      truncated: totalShapes > MAX_SHAPES,
    }),
    refresh: (recapture) => scheduleRefresh(recapture),
    status: () => status,
    statusText: () => status,
    backend: () => "webgpu",
    dpr: () => dpr,
    renderRunning: () => renderRunning,
    captureQueued: () => captureQueued,
    captureCount: () => captureCount,
    frameMs: () => lastFrameMs,
    lastError: null,
    bgTextureHeight: 0,
    captureMs: 0,
    captureScale: 1,
    shapeCount: 0,
    totalShapes: 0,
    truncated: false,
    captureStage: "idle",
    captureStart: 0,
  };
})();
