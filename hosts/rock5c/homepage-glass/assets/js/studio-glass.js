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
  const BLUR_RADIUS = 1;
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
    tickMouse(now);
    updateGlassState();
    window.HomepageGlassWebGPU.render();
    lastFrameMs = performance.now() - frameStart;
    scheduleNextFrame(scheduleNext);
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

  const gaussianKernel = (radius) => {
    const sigma = radius / 3.0;
    const kernel = [];
    let sum = 0;
    for (let i = 0; i <= radius; i++) {
      const weight = Math.exp((-0.5 * i * i) / (sigma * sigma));
      kernel.push(weight);
      sum += i === 0 ? weight : weight * 2;
    }
    return kernel.map((w) => w / sum);
  };

  const twoPassBlur = (source, radius) => {
    const weights = gaussianKernel(radius);
    const width = source.width;
    const height = source.height;
    const src = source.getContext("2d", { willReadFrequently: true });
    const image = src.getImageData(0, 0, width, height);
    const data = image.data;
    const horizontal = new Uint8ClampedArray(data);
    const vertical = new Uint8ClampedArray(data);

    for (let y = 0; y < height; y++) {
      const row = y * width * 4;
      for (let x = 0; x < width; x++) {
        let r = 0;
        let g = 0;
        let b = 0;
        let a = 0;
        for (let i = -radius; i <= radius; i++) {
          const xi = Math.min(width - 1, Math.max(0, x + i));
          const o = row + xi * 4;
          const w = weights[Math.abs(i)];
          r += data[o] * w;
          g += data[o + 1] * w;
          b += data[o + 2] * w;
          a += data[o + 3] * w;
        }
        const o = row + x * 4;
        horizontal[o] = r;
        horizontal[o + 1] = g;
        horizontal[o + 2] = b;
        horizontal[o + 3] = a;
      }
    }

    for (let y = 0; y < height; y++) {
      const row = y * width * 4;
      for (let x = 0; x < width; x++) {
        let r = 0;
        let g = 0;
        let b = 0;
        let a = 0;
        for (let i = -radius; i <= radius; i++) {
          const yi = Math.min(height - 1, Math.max(0, y + i));
          const o = yi * width * 4 + x * 4;
          const w = weights[Math.abs(i)];
          r += horizontal[o] * w;
          g += horizontal[o + 1] * w;
          b += horizontal[o + 2] * w;
          a += horizontal[o + 3] * w;
        }
        const o = row + x * 4;
        vertical[o] = r;
        vertical[o + 1] = g;
        vertical[o + 2] = b;
        vertical[o + 3] = a;
      }
    }

    const output = document.createElement("canvas");
    output.width = width;
    output.height = height;
    output
      .getContext("2d")
      .putImageData(new ImageData(vertical, width, height), 0, 0);
    return output;
  };

  const paintPageBackground = (ctx, width, height, scale = 1) => {
    const gradient = ctx.createLinearGradient(0, 0, 0, height);
    gradient.addColorStop(0, "#0b1020");
    gradient.addColorStop(0.52, "#101a2e");
    gradient.addColorStop(1, "#0a0e18");
    ctx.fillStyle = gradient;
    ctx.fillRect(0, 0, width, height);
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
      window.HomepageGlassWebGPU.setTextures(placeholder, placeholder);
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
      if (token !== captureToken) return;
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
        window.HomepageStudioGlass.captureStage = "blur";
      }
      const blurOut = twoPassBlur(out, BLUR_RADIUS);
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.captureStage = "upload";
      }
      if (window.HomepageGlassWebGPU) {
        updateGlassState();
        window.HomepageGlassWebGPU.setTextures(out, blurOut);
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
    });
  };

  const runCapture = () => {
    if (captureInFlight) {
      captureQueued = true;
      return Promise.resolve();
    }
    captureInFlight = true;
    let hungTimer = window.setTimeout(() => {
      captureToken += 1;
      captureInFlight = false;
      captureQueued = false;
      status = "capture-failed";
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.captureStage = "failed";
        window.HomepageStudioGlass.lastError = "capture hung";
      }
    }, 90000);
    const attempt = async (left) => {
      try {
        await captureBackground();
        if (hungTimer) window.clearTimeout(hungTimer);
        captureCount += 1;
        status = "running";
        if (window.HomepageStudioGlass) {
          window.HomepageStudioGlass.lastError = null;
          window.HomepageStudioGlass.captureStage = "done";
        }
      } catch (error) {
        if (hungTimer) window.clearTimeout(hungTimer);
        if (window.HomepageStudioGlass) {
          window.HomepageStudioGlass.captureStage = "failed";
          window.HomepageStudioGlass.lastError = error.message;
        }
        if (left > 0) {
          await new Promise((resolve) =>
            window.setTimeout(resolve, 2000 * (3 - left + 1))
          );
          return attempt(left - 1);
        }
        console.warn("studio glass capture failed", error);
        status = "capture-failed";
      }
    };
    return attempt(3).then(() => {
        captureInFlight = false;
        if (captureQueued) {
          captureQueued = false;
          return runCapture();
        }
      });
  };

  const scheduleRefresh = (recapture) => {
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
    probe: () => null, // WebGPU canvas has no synchronous readback; debug via status()
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
