// WebGL renderer adapted from iyinchao/liquid-glass-studio.
// Reference: https://github.com/iyinchao/liquid-glass-studio
// Shader math mirrors src/shaders/fragment-main.glsl STEP 9 (transparent
// liquid glass, near-zero blur) and src/shaders/fragment-bg.glsl shadow.
(() => {
  "use strict";

  const MAX_SHAPES = 128;
  const BALL_RADIUS_CSS = 100;
  const BLUR_RADIUS = 1;
  const SHAPE_ROUNDNESS = 5;
  const MERGE_RATE = 0.05;
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

  const VERTEX = `#version 300 es
in vec2 a_position;
out vec2 v_uv;
void main() {
  v_uv = a_position * 0.5 + 0.5;
  gl_Position = vec4(a_position, 0.0, 1.0);
}`;

  // Faithful port of the reference STEP 9 fragment shader, generalized to
  // MAX_SHAPES rounded rectangles plus the liquid mouse ball.
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
uniform vec2 u_scroll;
uniform vec2 u_origin;
uniform float u_dpr;
uniform float u_captureScale;
uniform int u_shapeCount;
uniform vec4 u_shapes[MAX_SHAPES];
uniform float u_radii[MAX_SHAPES];
uniform vec2 u_mouseSpring;
uniform vec2 u_mouseVelocity;
uniform float u_mergeRate;
uniform float u_springSizeFactor;
uniform float u_ballRadius;
uniform vec4 u_tint;
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
uniform int u_blurEdge;
uniform float u_roundness;
uniform float u_time;
uniform float u_shadowExpand;
uniform float u_shadowFactor;
uniform vec2 u_shadowOffset;

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

float safeAsin(float x) {
  return asin(clamp(x, -1.0, 1.0));
}

float sdCircle(vec2 p, float r) {
  return length(p) - r;
}

float superellipseCornerSDF(vec2 p, float r, float n) {
  p = abs(p);
  float v = pow(pow(p.x, n) + pow(p.y, n), 1.0 / n);
  return v - r;
}

float roundedRectSDF(vec2 p, vec2 center, float width, float height, float cornerRadius, float n) {
  p -= center;
  float cr = cornerRadius * u_dpr;
  vec2 d = abs(p) - vec2(width * u_dpr, height * u_dpr) * 0.5;
  float dist;
  if (d.x > -cr && d.y > -cr) {
    vec2 cornerCenter = sign(p) * (vec2(width * u_dpr, height * u_dpr) * 0.5 - vec2(cr));
    vec2 cornerP = p - cornerCenter;
    dist = superellipseCornerSDF(cornerP, cr, n);
  } else {
    dist = min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
  }
  return dist;
}

float smin(float a, float b, float k) {
  float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

// pageCss is in CSS pixels, top-down, relative to the document origin.
// The returned distance is normalized by the CSS viewport height exactly
// like the reference mainSDF.
float mergedAt(vec2 pageCss) {
  vec2 p = pageCss / u_resolution.y * u_dpr;
  float d = 1e20;
  float margin = u_ballRadius + 80.0;
  for (int i = 0; i < MAX_SHAPES; i++) {
    if (i >= u_shapeCount) break;
    vec4 s = u_shapes[i];
    if (pageCss.x < s.x - margin || pageCss.x > s.x + s.z + margin ||
        pageCss.y < s.y - margin || pageCss.y > s.y + s.w + margin) {
      continue;
    }
    vec2 center = (s.xy + s.zw * 0.5) / u_resolution.y * u_dpr;
    float w = s.z / u_resolution.y;
    float h = s.w / u_resolution.y;
    float r = u_radii[i] / u_resolution.y;
    float sd = roundedRectSDF(p, center, w, h, r, u_roundness);
    d = smin(d, sd, u_mergeRate);
  }
  vec2 ballCenter = u_mouseSpring / u_resolution.y * u_dpr;
  float ballRadius = u_ballRadius * u_dpr / u_resolution.y;
  float pulse = 1.0 + 0.02 * sin(u_time * 1.4);
  float stretch = clamp(length(u_mouseVelocity) * u_springSizeFactor * 0.00002, 0.0, 0.5);
  ballRadius *= pulse * (1.0 + stretch);
  float ball = sdCircle(p - ballCenter, ballRadius);
  return smin(d, ball, u_mergeRate);
}

vec2 getNormal(vec2 pageCss) {
  vec2 h = max(vec2(abs(dFdx(gl_FragCoord.x)), abs(dFdy(gl_FragCoord.y))), vec2(0.0001));
  vec2 step = h / u_dpr;
  vec2 grad = vec2(
    mergedAt(pageCss + vec2(step.x, 0.0)) - mergedAt(pageCss - vec2(step.x, 0.0)),
    mergedAt(pageCss + vec2(0.0, step.y)) - mergedAt(pageCss - vec2(0.0, step.y))
  ) / (2.0 * h);
  return grad * 1414.213562;
}

float vec2ToAngle(vec2 v) {
  float angle = atan(v.y, v.x);
  if (angle < 0.0) angle += 2.0 * PI;
  return angle;
}

vec4 getTextureDispersion(
  sampler2D tex1,
  sampler2D tex2,
  float mixRate,
  vec2 uv,
  vec2 offset,
  float factor
) {
  const float N_R = 1.0 - 0.02;
  const float N_G = 1.0;
  const float N_B = 1.0 + 0.02;
  float bgR = texture(tex1, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
  float bgG = texture(tex1, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
  float bgB = texture(tex1, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;
  float blurR = texture(tex2, uv + offset * (1.0 - (N_R - 1.0) * factor)).r;
  float blurG = texture(tex2, uv + offset * (1.0 - (N_G - 1.0) * factor)).g;
  float blurB = texture(tex2, uv + offset * (1.0 - (N_B - 1.0) * factor)).b;
  return vec4(
    mix(bgR, blurR, mixRate),
    mix(bgG, blurG, mixRate),
    mix(bgB, blurB, mixRate),
    1.0
  );
}

void main() {
  vec2 viewportCss = (vec2(gl_FragCoord.x, u_resolution.y - gl_FragCoord.y)) / u_dpr;
  vec2 pageCss = viewportCss + u_scroll;
  vec2 uv = (pageCss - u_origin) * u_captureScale / u_textureSize;

  float merged = mergedAt(pageCss);
  float shadow = exp(
    -1.0 / u_shadowExpand *
      abs(mergedAt(pageCss + u_shadowOffset)) *
      (u_resolution.y / u_dpr)
  ) * 0.6 * u_shadowFactor;

  vec4 outColor;
  if (merged < 0.005) {
    float nmerged = -1.0 * merged * (u_resolution.y / u_dpr);
    float xRatio = 1.0 - nmerged / u_refThickness;
    float thetaI = safeAsin(pow(xRatio, 2.0));
    float thetaT = safeAsin(1.0 / u_refFactor * sin(thetaI));
    float edgeFactor = -1.0 * tan(thetaT - thetaI);
    if (nmerged >= u_refThickness) edgeFactor = 0.0;

    if (edgeFactor <= 0.0) {
      outColor = texture(u_blurredBg, uv);
      outColor = mix(outColor, vec4(u_tint.rgb, 1.0), u_tint.a * 0.8);
    } else {
      float edgeH = nmerged / u_refThickness;
      vec2 normal = getNormal(pageCss);
      vec2 offset =
        -normal *
        edgeFactor *
        0.05 *
        u_dpr *
        vec2(u_resolution.y / u_resolution.x, 1.0);
      vec4 blurredPixel = getTextureDispersion(
        u_bg,
        u_blurredBg,
        u_blurEdge > 0 ? 1.0 : edgeH,
        uv,
        offset,
        u_refDispersion
      );
      outColor = mix(blurredPixel, vec4(u_tint.rgb, 1.0), u_tint.a * 0.8);

      float fresnelFactor = clamp(
        pow(
          1.0 +
            merged * (u_resolution.y / u_dpr) / 1500.0 *
              pow(500.0 / u_refFresnelRange, 2.0) +
            u_refFresnelHardness,
          5.0
        ),
        0.0,
        1.0
      );
      vec3 fresnelTintLCH = SRGB_TO_LCH(
        mix(vec3(1.0), u_tint.rgb, u_tint.a * 0.5)
      );
      fresnelTintLCH.x += 20.0 * fresnelFactor * u_refFresnelFactor;
      fresnelTintLCH.x = clamp(fresnelTintLCH.x, 0.0, 100.0);
      outColor = mix(
        outColor,
        vec4(LCH_TO_SRGB(fresnelTintLCH), 1.0),
        fresnelFactor * u_refFresnelFactor * 0.7 * length(normal)
      );

      float glareGeoFactor = clamp(
        pow(
          1.0 +
            merged * (u_resolution.y / u_dpr) / 1500.0 *
              pow(500.0 / u_glareRange, 2.0) +
            u_glareHardness,
          5.0
        ),
        0.0,
        1.0
      );
      float glareAngle =
        (vec2ToAngle(normalize(normal)) - PI / 4.0 + u_glareAngle) * 2.0;
      int glareFarside = 0;
      if (
        (glareAngle > PI * (2.0 - 0.5) && glareAngle < PI * (4.0 - 0.5)) ||
        glareAngle < PI * (0.0 - 0.5)
      ) {
        glareFarside = 1;
      }
      float glareAngleFactor =
        (0.5 + sin(glareAngle) * 0.5) *
        (glareFarside == 1 ? 1.2 * u_glareOppositeFactor : 1.2) *
        u_glareFactor;
      glareAngleFactor = clamp(
        pow(glareAngleFactor, 0.1 + u_glareConvergence * 2.0),
        0.0,
        1.0
      );

      vec3 glareTintLCH = SRGB_TO_LCH(
        mix(blurredPixel.rgb, u_tint.rgb, u_tint.a * 0.5)
      );
      glareTintLCH.x += 150.0 * glareAngleFactor * glareGeoFactor;
      glareTintLCH.y += 30.0 * glareAngleFactor * glareGeoFactor;
      glareTintLCH.x = clamp(glareTintLCH.x, 0.0, 120.0);
      outColor = mix(
        outColor,
        vec4(LCH_TO_SRGB(glareTintLCH), 1.0),
        glareAngleFactor * glareGeoFactor * length(normal)
      );
    }
  } else {
    outColor = texture(u_bg, uv);
  }

  outColor = mix(outColor, texture(u_bg, uv), smoothstep(-0.001, 0.001, merged));
  float alpha = 1.0 - smoothstep(0.0, 0.002, merged);
  if (merged < 0.0) {
    outColor.rgb = max(outColor.rgb - vec3(shadow), 0.0);
  }
  if (merged > 0.002) {
    fragColor = vec4(0.0, 0.0, 0.0, clamp(shadow, 0.0, 1.0));
  } else {
    fragColor = vec4(outColor.rgb, alpha);
  }
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
  let mouse = { x: -4000, y: -4000 };
  let mouseSpring = { x: -4000, y: -4000 };
  let mouseVelocity = { x: 0, y: 0 };
  let lastTick = performance.now();
  let dpr = 1;
  let rafId = 0;
  let getTargets = null;
  let uniformLocations = null;
  let renderRunning = false;
  let scrollRaf = 0;
  let captureRetries = 0;
  let captureStart = 0;
  let startTime = performance.now();
  let canvasAttached = false;
  let origin = { x: 0, y: 0 };
  let started = false;
  let status = "idle";
  let resizeTimer = 0;
  let refreshTimer = 0;
  let rootEl = null;
  let zIndex = 5;
  let reducedMotion = false;
  let captureInFlight = false;
  let captureQueued = false;
  let captureCount = 0;
  let totalShapes = 0;
  let lastError = null;
  const reducedMotionQuery = window.matchMedia("(prefers-reduced-motion: reduce)");

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
      scroll: gl.getUniformLocation(program, "u_scroll"),
      origin: gl.getUniformLocation(program, "u_origin"),
      dpr: gl.getUniformLocation(program, "u_dpr"),
      captureScale: gl.getUniformLocation(program, "u_captureScale"),
      shapeCount: gl.getUniformLocation(program, "u_shapeCount"),
      shapes: gl.getUniformLocation(program, "u_shapes"),
      radii: gl.getUniformLocation(program, "u_radii"),
      mouseSpring: gl.getUniformLocation(program, "u_mouseSpring"),
      mouseVelocity: gl.getUniformLocation(program, "u_mouseVelocity"),
      mergeRate: gl.getUniformLocation(program, "u_mergeRate"),
      springSizeFactor: gl.getUniformLocation(program, "u_springSizeFactor"),
      ballRadius: gl.getUniformLocation(program, "u_ballRadius"),
      tint: gl.getUniformLocation(program, "u_tint"),
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
      blurEdge: gl.getUniformLocation(program, "u_blurEdge"),
      roundness: gl.getUniformLocation(program, "u_roundness"),
      time: gl.getUniformLocation(program, "u_time"),
      shadowExpand: gl.getUniformLocation(program, "u_shadowExpand"),
      shadowFactor: gl.getUniformLocation(program, "u_shadowFactor"),
      shadowOffset: gl.getUniformLocation(program, "u_shadowOffset"),
    };
  };

  const getScroll = () => {
    const container = rootEl;
    if (container) {
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

  const render = (now, scheduleNext = true) => {
    if (!gl || !program || !bgTexture || gl.isContextLost()) {
      renderRunning = false;
      return;
    }
    tickMouse(now);
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

    const scroll = getScroll();
    updateOrigin();
    gl.uniform2f(uniformLocations.resolution, width, height);
    gl.uniform2f(uniformLocations.textureSize, bgTexture.width, bgTexture.height);
    gl.uniform2f(uniformLocations.scroll, scroll.x, scroll.y);
    gl.uniform2f(uniformLocations.origin, origin.x, origin.y);
    gl.uniform1f(uniformLocations.dpr, dpr);
    gl.uniform1f(uniformLocations.captureScale, captureScale);
    gl.uniform1i(uniformLocations.shapeCount, shapeCount);
    if (shapeCount > 0) {
      gl.uniform4fv(uniformLocations.shapes, shapeArray);
      gl.uniform1fv(uniformLocations.radii, radiusArray);
    }
    gl.uniform2f(
      uniformLocations.mouseSpring,
      mouseSpring.x + scroll.x,
      mouseSpring.y + scroll.y
    );
    gl.uniform2f(uniformLocations.mouseVelocity, mouseVelocity.x, mouseVelocity.y);
    gl.uniform1f(uniformLocations.mergeRate, MERGE_RATE);
    gl.uniform1f(uniformLocations.springSizeFactor, SPRING_SIZE_FACTOR);
    gl.uniform1f(uniformLocations.ballRadius, BALL_RADIUS_CSS);
    gl.uniform4f(uniformLocations.tint, 1, 1, 1, 0);
    gl.uniform1f(uniformLocations.refThickness, REF_THICKNESS);
    gl.uniform1f(uniformLocations.refFactor, REF_FACTOR);
    gl.uniform1f(uniformLocations.refDispersion, REF_DISPERSION);
    gl.uniform1f(uniformLocations.refFresnelRange, REF_FRESNEL_RANGE);
    gl.uniform1f(uniformLocations.refFresnelHardness, REF_FRESNEL_HARDNESS);
    gl.uniform1f(uniformLocations.refFresnelFactor, REF_FRESNEL_FACTOR);
    gl.uniform1f(uniformLocations.glareRange, GLARE_RANGE);
    gl.uniform1f(uniformLocations.glareHardness, GLARE_HARDNESS);
    gl.uniform1f(uniformLocations.glareFactor, GLARE_FACTOR);
    gl.uniform1f(uniformLocations.glareConvergence, GLARE_CONVERGENCE);
    gl.uniform1f(uniformLocations.glareOppositeFactor, GLARE_OPPOSITE_FACTOR);
    gl.uniform1f(uniformLocations.glareAngle, GLARE_ANGLE);
    gl.uniform1i(uniformLocations.blurEdge, 1);
    gl.uniform1f(uniformLocations.roundness, SHAPE_ROUNDNESS);
    gl.uniform1f(uniformLocations.time, (performance.now() - startTime) / 1000);
    gl.uniform1f(uniformLocations.shadowExpand, SHADOW_EXPAND);
    gl.uniform1f(uniformLocations.shadowFactor, SHADOW_FACTOR);
    gl.uniform2f(uniformLocations.shadowOffset, 0, 10);
    gl.drawArrays(gl.TRIANGLES, 0, 6);

    if (
      scheduleNext &&
      !document.hidden &&
      (!reducedMotion || Date.now() - lastInteraction < 1500)
    ) {
      rafId = window.requestAnimationFrame(render);
    } else {
      renderRunning = false;
    }
  };

  const startRender = () => {
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

  const paintPageBackground = (ctx, width, height) => {
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
    ctx.fillStyle = "rgba(255,255,255,0.016)";
    for (let y = 0; y < height; y += 34) {
      ctx.fillRect(0, y, width, 1);
    }
    for (let x = 0; x < width; x += 34) {
      ctx.fillRect(x, 0, 1, height);
    }
  };

  const makeTexture = (source) => {
    const texture = gl.createTexture();
    gl.bindTexture(gl.TEXTURE_2D, texture);
    gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, false);
    gl.texImage2D(
      gl.TEXTURE_2D,
      0,
      gl.RGBA,
      gl.RGBA,
      gl.UNSIGNED_BYTE,
      source
    );
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
    texture.width = source.width;
    texture.height = source.height;
    return texture;
  };

  const createPlaceholderTextures = () => {
    const container = rootEl;
    const rootWidth = container ? container.scrollWidth : window.innerWidth;
    const rootHeight = container ? container.scrollHeight : window.innerHeight;
    const width = Math.max(2, Math.round(rootWidth));
    const height = Math.max(2, Math.round(rootHeight));
    const placeholder = document.createElement("canvas");
    placeholder.width = width;
    placeholder.height = height;
    paintPageBackground(placeholder.getContext("2d"), width, height);
    captureScale = 1;

    const newBg = makeTexture(placeholder);
    const newBlur = makeTexture(placeholder);
    if (bgTexture) gl.deleteTexture(bgTexture);
    if (blurredTexture) gl.deleteTexture(blurredTexture);
    bgTexture = newBg;
    blurredTexture = newBlur;
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
    const maxEdge = Math.min(gl.getParameter(gl.MAX_TEXTURE_SIZE), MAX_TEXTURE_EDGE);
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
      paintPageBackground(ctx, out.width, out.height);
      ctx.filter = "saturate(1.22) contrast(1.04) brightness(0.96)";
      ctx.drawImage(snapshot, 0, 0);
      ctx.filter = "none";
      const darkTop = ctx.createLinearGradient(0, 0, 0, out.height);
      darkTop.addColorStop(0, "rgba(90,120,255,0.10)");
      darkTop.addColorStop(0.28, "rgba(90,120,255,0)");
      darkTop.addColorStop(1, "rgba(90,120,255,0)");
      ctx.fillStyle = darkTop;
      ctx.fillRect(0, 0, out.width, out.height);
      const darkBottom = ctx.createLinearGradient(0, 0, 0, out.height);
      darkBottom.addColorStop(0, "rgba(5,8,14,0)");
      darkBottom.addColorStop(0.86, "rgba(5,8,14,0.52)");
      darkBottom.addColorStop(1, "rgba(5,8,14,0.52)");
      ctx.fillStyle = darkBottom;
      ctx.fillRect(0, 0, out.width, out.height);

      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.captureStage = "blur";
      }
      const blurOut = twoPassBlur(out, BLUR_RADIUS);
      if (window.HomepageStudioGlass) {
        window.HomepageStudioGlass.captureStage = "upload";
      }
      const newBg = makeTexture(out);
      const newBlur = makeTexture(blurOut);
      if (bgTexture) gl.deleteTexture(bgTexture);
      if (blurredTexture) gl.deleteTexture(blurredTexture);
      bgTexture = newBg;
      blurredTexture = newBlur;
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
    if (captureCount > 0 && canvas) {
      canvas.classList.add("is-capturing");
    }
    return captureBackground()
      .then(() => {
        captureCount += 1;
        if (canvas) canvas.classList.remove("is-capturing");
      })
      .catch((error) => {
        lastError = error;
        if (window.HomepageStudioGlass) {
          window.HomepageStudioGlass.captureStage = "failed";
          window.HomepageStudioGlass.lastError = error.message;
        }
        console.warn("studio glass capture failed", error);
        createPlaceholderTextures();
        startRender();
      })
      .then(() => {
        captureInFlight = false;
        if (captureQueued) {
          captureQueued = false;
          return runCapture();
        }
      });
  };

  const scheduleRefresh = (recapture) => {
    if (refreshTimer) window.clearTimeout(refreshTimer);
    refreshTimer = window.setTimeout(() => {
      refreshTimer = 0;
      if (getTargets) refreshShapes();
      if (recapture && gl) {
        runCapture().then(() => startRender());
      } else {
        startRender();
      }
    }, recapture ? 180 : 0);
  };

  const start = (options) => {
    const config =
      typeof options === "function" ? { targetFn: options } : options || {};
    getTargets = config.targetFn || null;
    rootEl = config.root || document.getElementById("inner_wrapper") || null;
    zIndex = config.zIndex || 5;
    reducedMotion = reducedMotionQuery.matches;
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
    if (started) return true;
    if (!window.WebGL2RenderingContext || typeof window.html2canvas !== "function") {
      status = "unavailable";
      return false;
    }
    try {
      canvas = document.createElement("canvas");
      gl = canvas.getContext("webgl2", {
        alpha: true,
        premultipliedAlpha: false,
        antialias: false,
      });
      if (!gl) {
        status = "webgl2-unavailable";
        return false;
      }
      createProgram();
      dpr = window.devicePixelRatio || 1;
      refreshShapes();
      createPlaceholderTextures();
      if (!canvasAttached) {
        canvasAttached = true;
        canvas.className = "studio-glass-canvas";
        canvas.setAttribute("aria-hidden", "true");
        canvas.style.cssText =
          "position:fixed;inset:0;z-index:" +
          zIndex +
          ";pointer-events:none;";
        document.body.appendChild(canvas);

        const onPointer = (event) => {
          mouse.x = event.clientX;
          mouse.y = event.clientY;
          lastTick = performance.now();
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
              dpr = window.devicePixelRatio || 1;
              refreshShapes();
              scheduleRefresh(true);
            }, 220);
          },
          { passive: true }
        );
        canvas.addEventListener("webglcontextlost", (event) => {
          event.preventDefault();
          if (rafId) window.cancelAnimationFrame(rafId);
          renderRunning = false;
          status = "context-lost";
        });
        canvas.addEventListener("webglcontextrestored", () => {
          try {
            createProgram();
            createPlaceholderTextures();
            runCapture()
              .then(() => startRender())
              .catch(() => {});
            status = "running";
          } catch (error) {
            status = "restore-failed";
          }
        });
        document.addEventListener("visibilitychange", () => {
          if (document.hidden) {
            renderRunning = false;
          } else {
            startRender();
          }
        });
      }
      startRender();
      const captureWithRetry = () => {
        runCapture()
          .then(() => startRender())
          .catch(() => {
            if (captureRetries < 3) {
              captureRetries += 1;
              window.setTimeout(captureWithRetry, 2000);
            } else {
              status = "capture-failed";
            }
          });
      };
      captureWithRetry();
      started = true;
      status = "running";
      return true;
    } catch (error) {
      status = "start-failed: " + error.message;
      console.error("studio glass failed", error);
      return false;
    }
  };

  window.HomepageStudioGlass = {
    start,
    scheduleRefresh,
    probe: (x, y) => {
      if (!gl || !canvas) return null;
      if (rafId) window.cancelAnimationFrame(rafId);
      rafId = 0;
      renderRunning = true;
      render(performance.now(), false);
      const pixels = new Uint8Array(4);
      gl.readPixels(x, y, 1, 1, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
      renderRunning = false;
      return Array.from(pixels);
    },
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
