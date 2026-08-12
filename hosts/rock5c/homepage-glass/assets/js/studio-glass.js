// WebGL renderer adapted from iyinchao/liquid-glass-studio.
(() => {
  const MAX_SHAPES = 64;

  const VERTEX = `#version 300 es
in vec2 a_position;
out vec2 v_uv;
void main() {
  v_uv = a_position * 0.5 + 0.5;
  gl_Position = vec4(a_position, 0.0, 1.0);
}`;

  const FRAGMENT = `#version 300 es
precision highp float;

#define MAX_SHAPES ${MAX_SHAPES}
#define PI 3.14159265359

in vec2 v_uv;
out vec4 fragColor;

uniform sampler2D u_bg;
uniform sampler2D u_blurredBg;
uniform vec2 u_resolution;
uniform vec2 u_textureSize;
uniform float u_scrollY;
uniform float u_dpr;
uniform float u_captureScale;
uniform int u_shapeCount;
uniform vec4 u_shapes[MAX_SHAPES];
uniform float u_radii[MAX_SHAPES];
uniform vec2 u_mouseSpring;
uniform float u_mergeRate;
uniform float u_refThickness;
uniform float u_refFactor;
uniform float u_refDispersion;
uniform float u_refFresnelRange;
uniform float u_refFresnelHardness;
uniform float u_refFresnelFactor;
uniform float u_glareRange;
uniform float u_glareHardness;
uniform float u_glareFactor;
uniform float u_glareConvergence;
uniform float u_glareOppositeFactor;
uniform float u_glareAngle;
uniform float u_ballRadius;
uniform float u_tint;
uniform float u_blurRadius;
uniform int u_blurEdge;

const vec3 D65_WHITE = vec3(0.95045592705, 1.0, 1.08905775076);
const mat3 RGB_TO_XYZ_M = mat3(
  0.4124, 0.3576, 0.1805,
  0.2126, 0.7152, 0.0722,
  0.0193, 0.1192, 0.9505
);
const mat3 XYZ_TO_RGB_M = mat3(
  3.2406255, -1.537208, -0.4986286,
  -0.9689307, 1.8757561, 0.0415175,
  0.0557101, -0.2040211, 1.0569959
);
float UNCOMPAND_SRGB(float a) {
  return a > 0.04045 ? pow((a + 0.055) / 1.055, 2.4) : a / 12.92;
}
float COMPAND_RGB(float a) {
  return a <= 0.0031308 ? 12.92 * a : 1.055 * pow(a, 0.41666666666) - 0.055;
}
vec3 SRGB_TO_XYZ(vec3 srgb) {
  vec3 linear = vec3(UNCOMPAND_SRGB(srgb.r), UNCOMPAND_SRGB(srgb.g), UNCOMPAND_SRGB(srgb.b));
  return linear * RGB_TO_XYZ_M;
}
vec3 XYZ_TO_SRGB(vec3 xyz) {
  vec3 linear = xyz * XYZ_TO_RGB_M;
  return vec3(COMPAND_RGB(linear.r), COMPAND_RGB(linear.g), COMPAND_RGB(linear.b));
}
float XYZ_TO_LAB_F(float x) {
  return x > 0.00885645167 ? pow(x, 0.333333333) : 7.78703703704 * x + 0.13793103448;
}
vec3 XYZ_TO_LAB(vec3 xyz) {
  vec3 s = xyz / D65_WHITE;
  s = vec3(XYZ_TO_LAB_F(s.x), XYZ_TO_LAB_F(s.y), XYZ_TO_LAB_F(s.z));
  return vec3(116.0 * s.y - 16.0, 500.0 * (s.x - s.y), 200.0 * (s.y - s.z));
}
vec3 LAB_TO_LCH(vec3 lab) {
  return vec3(lab.x, sqrt(dot(lab.yz, lab.yz)), atan(lab.z, lab.y) * 57.2957795131);
}
vec3 SRGB_TO_LCH(vec3 srgb) {
  return LAB_TO_LCH(XYZ_TO_LAB(SRGB_TO_XYZ(srgb)));
}
float LAB_TO_XYZ_F(float x) {
  return x > 0.206897 ? x * x * x : 0.12841854934 * (x - 0.137931034);
}
vec3 LAB_TO_XYZ(vec3 lab) {
  float w = (lab.x + 16.0) / 116.0;
  return D65_WHITE * vec3(LAB_TO_XYZ_F(w + lab.y / 500.0), LAB_TO_XYZ_F(w), LAB_TO_XYZ_F(w - lab.z / 200.0));
}
vec3 LCH_TO_LAB(vec3 lch) {
  return vec3(lch.x, lch.y * cos(lch.z * 0.01745329251), lch.y * sin(lch.z * 0.01745329251));
}
vec3 LCH_TO_SRGB(vec3 lch) {
  return XYZ_TO_SRGB(LAB_TO_XYZ(LCH_TO_LAB(lch)));
}

float sdCircle(vec2 p, float r) {
  return length(p) - r;
}

float sdRoundRect(vec2 p, vec2 halfSize, float r) {
  vec2 d = abs(p) - halfSize;
  if (d.x > -r && d.y > -r) {
    vec2 c = abs(p) - (halfSize - vec2(r));
    float n = 4.0;
    float v = pow(pow(max(c.x, 0.0), n) + pow(max(c.y, 0.0), n), 1.0 / n);
    return v - r;
  }
  return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

vec2 pageCoord() {
  vec2 p = vec2(gl_FragCoord.x, u_resolution.y - gl_FragCoord.y);
  return p + vec2(0.0, u_scrollY);
}

float mergedSDF(vec2 p) {
  float d = 1e20;
  for (int i = 0; i < MAX_SHAPES; i++) {
    if (i >= u_shapeCount) break;
    vec2 center = u_shapes[i].xy + u_shapes[i].zw * 0.5;
    vec2 halfSize = u_shapes[i].zw * 0.5;
    d = min(d, sdRoundRect(p - center, halfSize, u_radii[i]));
  }
  float ball = sdCircle(p - u_mouseSpring, u_ballRadius * u_dpr);
  d = smin(d, ball, u_mergeRate * u_resolution.y);
  return d;
}

vec2 mergedNormal(vec2 p) {
  vec2 h = vec2(1.0, 1.0);
  float dx =
    mergedSDF(p + vec2(h.x, 0.0)) -
    mergedSDF(p - vec2(h.x, 0.0));
  float dy =
    mergedSDF(p + vec2(0.0, h.y)) -
    mergedSDF(p - vec2(0.0, h.y));
  return vec2(dx, dy);
}

vec4 getTextureDispersion(vec2 uv, vec2 offset, float mixRate, float factor) {
  const float N_R = 1.0 - 0.02;
  const float N_G = 1.0;
  const float N_B = 1.0 + 0.02;
  float bgR = texture(u_bg, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
  float bgG = texture(u_bg, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
  float bgB = texture(u_bg, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;
  float blurR = texture(u_blurredBg, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
  float blurG = texture(u_blurredBg, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
  float blurB = texture(u_blurredBg, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;
  return vec4(
    mix(bgR, blurR, mixRate),
    mix(bgG, blurG, mixRate),
    mix(bgB, blurB, mixRate),
    1.0
  );
}

void main() {
  vec2 p = pageCoord();
  float merged = mergedSDF(p);
  if (merged > 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 0.0);
    return;
  }

  vec2 uv = p * (u_captureScale / u_dpr) / u_textureSize;
  float dist = -merged;
  vec2 normal = mergedNormal(p);
  float distCss = dist / u_dpr;

  float xRatio = 1.0 - dist / u_refThickness;
  float thetaI = asin(clamp(pow(max(xRatio, 0.0), 2.0), 0.0, 1.0));
  float thetaT = asin(clamp(1.0 / u_refFactor * sin(thetaI), -1.0, 1.0));
  float edgeFactor = -tan(thetaT - thetaI);
  if (dist >= u_refThickness) edgeFactor = 0.0;
  float edgeH = clamp(dist / u_refThickness, 0.0, 1.0);

  vec4 color;
  if (merged < 0.005) {
    if (edgeFactor <= 0.0) {
      color = texture(u_blurredBg, uv);
      color = mix(color, vec4(1.0), u_tint * 0.8);
    } else {
      vec2 offset =
        -normal *
        edgeFactor *
        0.05 *
        u_dpr *
        vec2(u_resolution.y / u_resolution.x, 1.0);
      color = getTextureDispersion(
        uv,
        offset,
        u_blurEdge > 0 ? 1.0 : edgeH,
        u_refDispersion
      );
      color = mix(color, vec4(1.0), u_tint * 0.8);

      float fresnel = clamp(
        pow(
          1.0 -
            distCss / 1500.0 * pow(500.0 / u_refFresnelRange, 2.0) +
            u_refFresnelHardness,
          5.0
        ),
        0.0,
        1.0
      );
      vec3 fresnelLch = SRGB_TO_LCH(
        mix(vec3(1.0), vec3(1.0), u_tint * 0.5)
      );
      fresnelLch.x += 20.0 * fresnel * u_refFresnelFactor;
      fresnelLch.x = clamp(fresnelLch.x, 0.0, 100.0);
      color = mix(
        color,
        vec4(LCH_TO_SRGB(fresnelLch), 1.0),
        fresnel * u_refFresnelFactor * 0.7 * length(normal)
      );

      float glareGeo = clamp(
        pow(
          1.0 -
            distCss / 1500.0 * pow(500.0 / u_glareRange, 2.0) +
            u_glareHardness,
          5.0
        ),
        0.0,
        1.0
      );
      float angle = (atan(normal.y, normal.x) - PI / 4.0 + u_glareAngle) * 2.0;
      int farside = 0;
      if (
        (angle > PI * (2.0 - 0.5) && angle < PI * (4.0 - 0.5)) ||
        angle < PI * (0.0 - 0.5)
      ) {
        farside = 1;
      }
      float angleFactor =
        (0.5 + sin(angle) * 0.5) *
        (farside == 1 ? 1.2 * u_glareOppositeFactor : 1.2) *
        u_glareFactor;
      angleFactor = clamp(
        pow(angleFactor, 0.1 + u_glareConvergence * 2.0),
        0.0,
        1.0
      );
      vec3 glareLch = SRGB_TO_LCH(
        mix(color.rgb, vec3(1.0), u_tint * 0.5)
      );
      glareLch.x += 150.0 * angleFactor * glareGeo;
      glareLch.y += 30.0 * angleFactor * glareGeo;
      glareLch.x = clamp(glareLch.x, 0.0, 120.0);
      color = mix(
        color,
        vec4(LCH_TO_SRGB(glareLch), 1.0),
        angleFactor * glareGeo * length(normal)
      );
    }
  } else {
    color = texture(u_bg, uv);
  }

  color = mix(color, texture(u_bg, uv), smoothstep(-0.001, 0.001, merged));
  float alpha = 1.0 - smoothstep(-1.0, 1.0, merged);
  fragColor = vec4(color.rgb, alpha);
}`;

  let canvas = null;
  let gl = null;
  let program = null;
  let bgTexture = null;
  let blurredTexture = null;
  let captureScale = 1;
  let captureToken = 0;
  let shapeArray = null;
  let radiusArray = null;
  let shapeCount = 0;
  let mouse = { x: -2000, y: -2000 };
  let mouseSpring = { x: -2000, y: -2000 };
  let dpr = 1;
  let rafId = 0;
  let getTargets = null;
  let uniformLocations = null;
  let renderRunning = false;
  let lastInteraction = Date.now();
  let scrollRaf = 0;
  let captureRetries = 0;
  let canvasAttached = false;
  let captureStart = 0;

  const compileShader = (type, source) => {
    const shader = gl.createShader(type);
    gl.shaderSource(shader, source);
    gl.compileShader(shader);
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      throw new Error(gl.getShaderInfoLog(shader));
    }
    return shader;
  };

  const createProgram = () => {
    const vs = compileShader(gl.VERTEX_SHADER, VERTEX);
    const fs = compileShader(gl.FRAGMENT_SHADER, FRAGMENT);
    program = gl.createProgram();
    gl.attachShader(program, vs);
    gl.attachShader(program, fs);
    gl.linkProgram(program);
    if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
      throw new Error(gl.getProgramInfoLog(program));
    }
    gl.useProgram(program);

    const buffer = gl.createBuffer();
    gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
    gl.bufferData(
      gl.ARRAY_BUFFER,
      new Float32Array([-1, -1, 1, -1, -1, 1, -1, 1, 1, -1, 1, 1]),
      gl.STATIC_DRAW
    );
    const loc = gl.getAttribLocation(program, "a_position");
    gl.enableVertexAttribArray(loc);
    gl.vertexAttribPointer(loc, 2, gl.FLOAT, false, 0, 0);
    uniformLocations = {
      bg: gl.getUniformLocation(program, "u_bg"),
      blurredBg: gl.getUniformLocation(program, "u_blurredBg"),
      resolution: gl.getUniformLocation(program, "u_resolution"),
      textureSize: gl.getUniformLocation(program, "u_textureSize"),
      scrollY: gl.getUniformLocation(program, "u_scrollY"),
      dpr: gl.getUniformLocation(program, "u_dpr"),
      captureScale: gl.getUniformLocation(program, "u_captureScale"),
      shapeCount: gl.getUniformLocation(program, "u_shapeCount"),
      shapes: gl.getUniformLocation(program, "u_shapes"),
      radii: gl.getUniformLocation(program, "u_radii"),
      mouseSpring: gl.getUniformLocation(program, "u_mouseSpring"),
      mergeRate: gl.getUniformLocation(program, "u_mergeRate"),
      refThickness: gl.getUniformLocation(program, "u_refThickness"),
      refFactor: gl.getUniformLocation(program, "u_refFactor"),
      refDispersion: gl.getUniformLocation(program, "u_refDispersion"),
      refFresnelRange: gl.getUniformLocation(program, "u_refFresnelRange"),
      refFresnelHardness: gl.getUniformLocation(program, "u_refFresnelHardness"),
      refFresnelFactor: gl.getUniformLocation(program, "u_refFresnelFactor"),
      glareRange: gl.getUniformLocation(program, "u_glareRange"),
      glareHardness: gl.getUniformLocation(program, "u_glareHardness"),
      glareFactor: gl.getUniformLocation(program, "u_glareFactor"),
      glareConvergence: gl.getUniformLocation(program, "u_glareConvergence"),
      glareOppositeFactor: gl.getUniformLocation(program, "u_glareOppositeFactor"),
      glareAngle: gl.getUniformLocation(program, "u_glareAngle"),
      ballRadius: gl.getUniformLocation(program, "u_ballRadius"),
      tint: gl.getUniformLocation(program, "u_tint"),
      blurRadius: gl.getUniformLocation(program, "u_blurRadius"),
      blurEdge: gl.getUniformLocation(program, "u_blurEdge"),
    };
  };

  const getScrollTop = () => {
    const container = document.getElementById("inner_wrapper");
    if (container) return container.scrollTop;
    return window.pageYOffset || document.documentElement.scrollTop || 0;
  };

  const getScrollLeft = () => {
    const container = document.getElementById("inner_wrapper");
    if (container) return container.scrollLeft;
    return window.pageXOffset || document.documentElement.scrollLeft || 0;
  };

  const refreshShapes = () => {
    const elements = getTargets ? getTargets() : [];
    const visible = elements.filter((element) => {
      const rect = element.getBoundingClientRect();
      return rect.width > 0 && rect.height > 0;
    });
    shapeCount = Math.min(visible.length, MAX_SHAPES);
    shapeArray = new Float32Array(shapeCount * 4);
    radiusArray = new Float32Array(shapeCount);
    const scrollX = getScrollLeft();
    const scrollY = getScrollTop();
    visible.slice(0, shapeCount).forEach((element, i) => {
      const rect = element.getBoundingClientRect();
      const radius =
        parseFloat(getComputedStyle(element).borderRadius) || 20;
      shapeArray[i * 4] = (rect.left + scrollX) * dpr;
      shapeArray[i * 4 + 1] = (rect.top + scrollY) * dpr;
      shapeArray[i * 4 + 2] = rect.width * dpr;
      shapeArray[i * 4 + 3] = rect.height * dpr;
      radiusArray[i] = radius * dpr;
    });
  };

  const render = () => {
    if (!gl || !program || !bgTexture) return;
    tickMouse();
    const width = Math.round(window.innerWidth * dpr);
    const height = Math.round(window.innerHeight * dpr);
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
      canvas.style.width = window.innerWidth + "px";
      canvas.style.height = window.innerHeight + "px";
      gl.viewport(0, 0, width, height);
    }

    gl.clearColor(0, 0, 0, 0);
    gl.clear(gl.COLOR_BUFFER_BIT);
    gl.useProgram(program);
    gl.activeTexture(gl.TEXTURE0);
    gl.bindTexture(gl.TEXTURE_2D, bgTexture);
    gl.uniform1i(uniformLocations.bg, 0);
    gl.activeTexture(gl.TEXTURE1);
    gl.bindTexture(gl.TEXTURE_2D, blurredTexture);
    gl.uniform1i(uniformLocations.blurredBg, 1);
    gl.uniform2f(uniformLocations.resolution, width, height);
    gl.uniform2f(
      uniformLocations.textureSize,
      bgTexture.width,
      bgTexture.height
    );
    gl.uniform1f(uniformLocations.scrollY, getScrollTop() * dpr);
    gl.uniform1f(uniformLocations.dpr, dpr);
    gl.uniform1f(uniformLocations.captureScale, captureScale);
    gl.uniform1i(uniformLocations.shapeCount, shapeCount);
    if (shapeCount > 0) {
      gl.uniform4fv(uniformLocations.shapes, shapeArray);
      gl.uniform1fv(uniformLocations.radii, radiusArray);
    }
    gl.uniform2f(
      uniformLocations.mouseSpring,
      mouseSpring.x,
      mouseSpring.y + getScrollTop() * dpr
    );
    gl.uniform1f(uniformLocations.mergeRate, 0.05);
    gl.uniform1f(uniformLocations.refThickness, 20.0);
    gl.uniform1f(uniformLocations.refFactor, 1.4);
    gl.uniform1f(uniformLocations.refDispersion, 7.0);
    gl.uniform1f(uniformLocations.refFresnelRange, 30.0);
    gl.uniform1f(uniformLocations.refFresnelHardness, 0.2);
    gl.uniform1f(uniformLocations.refFresnelFactor, 0.2);
    gl.uniform1f(uniformLocations.glareRange, 30.0);
    gl.uniform1f(uniformLocations.glareHardness, 0.2);
    gl.uniform1f(uniformLocations.glareFactor, 0.9);
    gl.uniform1f(uniformLocations.glareConvergence, 0.5);
    gl.uniform1f(uniformLocations.glareOppositeFactor, 0.8);
    gl.uniform1f(uniformLocations.glareAngle, -0.785398);
    gl.uniform1f(uniformLocations.ballRadius, 100.0);
    gl.uniform1f(uniformLocations.tint, 0.0);
    gl.uniform1f(uniformLocations.blurRadius, 1.0);
    gl.uniform1i(uniformLocations.blurEdge, 1);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    if (Date.now() - lastInteraction < 1500) {
      rafId = window.requestAnimationFrame(render);
    } else {
      renderRunning = false;
    }
  };

  const startRender = () => {
    if (!renderRunning) {
      renderRunning = true;
      render();
    }
  };

  const tickMouse = () => {
    mouseSpring.x += (mouse.x - mouseSpring.x) * 0.08;
    mouseSpring.y += (mouse.y - mouseSpring.y) * 0.08;
  };

  const captureBackground = () => {
    const container = document.getElementById("inner_wrapper");
    const root = container || document.body;
    const token = ++captureToken;
    return window.html2canvas(root, {
      scale: Math.min(dpr, 2),
      width: container ? container.scrollWidth : window.innerWidth,
      height: container ? container.scrollHeight : window.innerHeight,
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
      allowTaint: true,
      backgroundColor: null,
      logging: false,
    }).then((snapshot) => {
      if (token !== captureToken) return;
      const rootWidth = container ? container.scrollWidth : window.innerWidth;
      captureScale = snapshot.width / rootWidth;

      const blurCanvas = document.createElement("canvas");
      blurCanvas.width = snapshot.width;
      blurCanvas.height = snapshot.height;
      const blurCtx = blurCanvas.getContext("2d");
      blurCtx.filter = "blur(2px)";
      blurCtx.drawImage(snapshot, 0, 0);

      const newBg = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, newBg);
      gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);
      gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        snapshot
      );
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      newBg.width = snapshot.width;
      newBg.height = snapshot.height;

      const newBlur = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, newBlur);
      gl.texImage2D(
        gl.TEXTURE_2D,
        0,
        gl.RGBA,
        gl.RGBA,
        gl.UNSIGNED_BYTE,
        blurCanvas
      );
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
      gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
      newBlur.width = blurCanvas.width;
      newBlur.height = blurCanvas.height;

      if (bgTexture) gl.deleteTexture(bgTexture);
      if (blurredTexture) gl.deleteTexture(blurredTexture);
      bgTexture = newBg;
      blurredTexture = newBlur;
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.bgTextureHeight = snapshot.height;
        window.HomepageStudioGlass.captureMs = performance.now() - captureStart;
      }
    });
  };

  const start = (targetFn) => {
    getTargets = targetFn;
    if (!window.WebGL2RenderingContext || typeof window.html2canvas !== "function") {
      return false;
    }
    try {
      canvas = document.createElement("canvas");
      gl = canvas.getContext("webgl2", { alpha: true, premultipliedAlpha: true });
      if (!gl) return false;
      createProgram();
      dpr = window.devicePixelRatio || 1;
      refreshShapes();
      captureStart = performance.now();
      const attachCanvas = () => {
        if (canvasAttached) return;
        canvasAttached = true;
          canvas.style.cssText =
            "position:fixed;inset:0;z-index:var(--homepage-glass-z);pointer-events:none;";
          document.body.appendChild(canvas);
          const onPointer = (event) => {
            mouse.x = event.clientX * dpr;
            mouse.y = event.clientY * dpr;
            lastInteraction = Date.now();
            startRender();
          };
          window.addEventListener("pointermove", onPointer, { passive: true });
          window.addEventListener("touchmove", onPointer, { passive: true });
          document.addEventListener(
            "scroll",
            () => {
              if (scrollRaf) return;
              scrollRaf = window.requestAnimationFrame(() => {
                scrollRaf = 0;
                lastInteraction = Date.now();
                startRender();
              });
            },
            { capture: true, passive: true }
          );
          window.addEventListener("resize", () => {
            dpr = window.devicePixelRatio || 1;
            refreshShapes();
            lastInteraction = Date.now();
            startRender();
            if (window.HomepageStudioGlass) {
              window.HomepageStudioGlass.refresh(true);
            }
          });
          startRender();
      };
      const captureWithRetry = () => {
        captureBackground()
          .then(attachCanvas)
          .catch(() => {
            if (captureRetries < 3) {
              captureRetries += 1;
              window.setTimeout(captureWithRetry, 2000);
            } else {
              if (canvas && canvas.parentNode) {
                canvas.parentNode.removeChild(canvas);
              }
              gl = null;
              console.error("studio glass capture failed");
            }
          });
      };
      captureWithRetry();
      return true;
    } catch (error) {
      console.error("studio glass failed", error);
      return false;
    }
  };

  window.HomepageStudioGlass = {
    start,
    refresh: (recapture) => {
      if (getTargets) refreshShapes();
      lastInteraction = Date.now();
      if (recapture && typeof window.html2canvas === "function" && gl) {
        captureBackground()
          .then(() => {
            lastInteraction = Date.now();
            startRender();
          })
          .catch(() => {});
        return;
      }
      startRender();
    },
  };
})();
