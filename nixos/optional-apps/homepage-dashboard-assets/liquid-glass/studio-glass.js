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
uniform vec2 u_resolution;
uniform vec2 u_textureSize;
uniform float u_scrollY;
uniform float u_dpr;
uniform int u_shapeCount;
uniform vec4 u_shapes[MAX_SHAPES];
uniform float u_radii[MAX_SHAPES];
uniform vec2 u_mouseSpring;
uniform float u_mergeRate;

const float REF_THICKNESS = 20.0;
const float REF_FACTOR = 1.4;
const float REF_DISPERSION = 7.0;
const float FRESNEL_RANGE = 30.0;
const float FRESNEL_HARDNESS = 0.2;
const float FRESNEL_FACTOR = 0.2;
const float GLARE_RANGE = 30.0;
const float GLARE_HARDNESS = 0.2;
const float GLARE_FACTOR = 0.9;
const float GLARE_CONVERGENCE = 0.5;
const float GLARE_OPPOSITE = 0.8;
const float GLARE_ANGLE = -0.785398;
const float BALL_RADIUS = 33.0;
const float TINT = 0.06;

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
  float ball = sdCircle(p - u_mouseSpring, BALL_RADIUS * u_dpr);
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
  return normalize(vec2(dx, dy));
}

vec4 sampleDisperse(vec2 uv, vec2 offset, float factor) {
  float r = texture(u_bg, uv + offset * (1.0 - 0.02 * factor)).r;
  float g = texture(u_bg, uv + offset).g;
  float b = texture(u_bg, uv + offset * (1.0 + 0.02 * factor)).b;
  return vec4(r, g, b, 1.0);
}

void main() {
  vec2 p = pageCoord();
  float merged = mergedSDF(p);
  if (merged > 0.0) {
    fragColor = vec4(0.0, 0.0, 0.0, 0.0);
    return;
  }

  vec2 uv = p / u_textureSize;
  float dist = -merged;
  vec2 normal = mergedNormal(p);

  float xRatio = 1.0 - dist / REF_THICKNESS;
  float thetaI = asin(clamp(pow(max(xRatio, 0.0), 2.0), 0.0, 1.0));
  float thetaT = asin(clamp(1.0 / REF_FACTOR * sin(thetaI), -1.0, 1.0));
  float edgeFactor = -tan(thetaT - thetaI);
  if (dist >= REF_THICKNESS) edgeFactor = 0.0;

  vec2 offset =
    -normal *
    edgeFactor *
    0.05 *
    u_dpr *
    vec2(u_resolution.y / u_resolution.x, 1.0);

  vec4 color = edgeFactor <= 0.0
    ? texture(u_bg, uv)
    : sampleDisperse(uv, offset, REF_DISPERSION);

  float distCss = dist / u_dpr;
  float fresnel = clamp(
    pow(
      1.0 -
        distCss / 1500.0 * pow(500.0 / FRESNEL_RANGE, 2.0) +
        FRESNEL_HARDNESS,
      5.0
    ),
    0.0,
    1.0
  );
  color = mix(color, vec4(1.0), fresnel * FRESNEL_FACTOR * 0.7);

  float glareGeo = clamp(
    pow(
      1.0 -
        distCss / 1500.0 * pow(500.0 / GLARE_RANGE, 2.0) +
        GLARE_HARDNESS,
      5.0
    ),
    0.0,
    1.0
  );
  float angle = (atan(normal.y, normal.x) - PI / 4.0 + GLARE_ANGLE) * 2.0;
  int farside = 0;
  if (
    (angle > PI * (2.0 - 0.5) && angle < PI * (4.0 - 0.5)) ||
    angle < PI * (0.0 - 0.5)
  ) {
    farside = 1;
  }
  float angleFactor =
    (0.5 + sin(angle) * 0.5) *
    (farside == 1 ? 1.2 * GLARE_OPPOSITE : 1.2) *
    GLARE_FACTOR;
  angleFactor = clamp(
    pow(angleFactor, 0.1 + GLARE_CONVERGENCE * 2.0),
    0.0,
    1.0
  );
  color = mix(color, vec4(1.0), angleFactor * glareGeo);
  color = mix(color, vec4(1.0), TINT);

  float alpha = 1.0 - smoothstep(-1.0, 1.0, merged);
  fragColor = vec4(color.rgb, alpha);
}`;

  let canvas = null;
  let gl = null;
  let program = null;
  let bgTexture = null;
  let shapeArray = null;
  let radiusArray = null;
  let shapeCount = 0;
  let mouse = { x: -2000, y: -2000 };
  let mouseSpring = { x: -2000, y: -2000 };
  let dpr = 1;
  let rafId = 0;
  let getTargets = null;

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
  };

  const getScrollTop = () => {
    const container = document.getElementById("inner_wrapper");
    if (container) return container.scrollTop || 0;
    return window.pageYOffset || document.documentElement.scrollTop || 0;
  };

  const refreshShapes = () => {
    const elements = getTargets ? getTargets() : [];
    shapeCount = Math.min(elements.length, MAX_SHAPES);
    shapeArray = new Float32Array(shapeCount * 4);
    radiusArray = new Float32Array(shapeCount);
    const scrollX = window.pageXOffset || document.documentElement.scrollLeft || 0;
    const scrollY = getScrollTop();
    elements.slice(0, shapeCount).forEach((element, i) => {
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
    gl.uniform1i(gl.getUniformLocation(program, "u_bg"), 0);
    gl.uniform2f(gl.getUniformLocation(program, "u_resolution"), width, height);
    gl.uniform2f(
      gl.getUniformLocation(program, "u_textureSize"),
      bgTexture.width,
      bgTexture.height
    );
    gl.uniform1f(
      gl.getUniformLocation(program, "u_scrollY"),
      getScrollTop() * dpr
    );
    gl.uniform1f(gl.getUniformLocation(program, "u_dpr"), dpr);
    gl.uniform1i(gl.getUniformLocation(program, "u_shapeCount"), shapeCount);
    if (shapeCount > 0) {
      gl.uniform4fv(gl.getUniformLocation(program, "u_shapes"), shapeArray);
      gl.uniform1fv(gl.getUniformLocation(program, "u_radii"), radiusArray);
    }
    gl.uniform2f(
      gl.getUniformLocation(program, "u_mouseSpring"),
      mouseSpring.x,
      mouseSpring.y + getScrollTop() * dpr
    );
    gl.uniform1f(gl.getUniformLocation(program, "u_mergeRate"), 0.05);
    gl.drawArrays(gl.TRIANGLES, 0, 6);
    rafId = window.requestAnimationFrame(render);
  };

  const tickMouse = () => {
    mouseSpring.x += (mouse.x - mouseSpring.x) * 0.08;
    mouseSpring.y += (mouse.y - mouseSpring.y) * 0.08;
  };

  const captureBackground = () =>
    window.html2canvas(document.body, {
      scale: Math.min(dpr, 2),
      useCORS: true,
      allowTaint: true,
      backgroundColor: null,
    }).then((snapshot) => {
      bgTexture = gl.createTexture();
      gl.bindTexture(gl.TEXTURE_2D, bgTexture);
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
      bgTexture.width = snapshot.width;
      bgTexture.height = snapshot.height;
    });

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
      captureBackground()
        .then(() => {
          canvas.className = "studio-glass-canvas";
          canvas.style.cssText =
            "position:fixed;inset:0;z-index:5;pointer-events:none;";
          document.body.appendChild(canvas);
          document.documentElement.classList.add("studio-glass");
          window.addEventListener("mousemove", (event) => {
            mouse.x = event.clientX * dpr;
            mouse.y = event.clientY * dpr;
          });
          document.addEventListener(
            "scroll",
            () => {
              if (getTargets) refreshShapes();
            },
            { capture: true, passive: true }
          );
          window.addEventListener("resize", () => {
            dpr = window.devicePixelRatio || 1;
            refreshShapes();
          });
          render();
        })
        .catch(() => {
          if (canvas && canvas.parentNode) canvas.parentNode.removeChild(canvas);
          gl = null;
          console.error("studio glass capture failed");
        });
      return true;
    } catch (error) {
      console.error("studio glass failed", error);
      return false;
    }
  };

  window.HomepageStudioGlass = {
    start,
    refresh: () => {
      if (getTargets) refreshShapes();
    },
  };
})();
