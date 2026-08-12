// WebGPU liquid glass backend (bg -> blur -> main), adapted from
// iyinchao/liquid-glass-studio WGSL shaders. The page snapshot and shape
// state are owned by studio-glass.js and pushed through the glassState
// object passed to init().
(() => {
  "use strict";

  const MAX_SHAPES = 128;

  const UNIFORM_OFFSETS = {
    resolution: 0,
    textureSize: 8,
    scroll: 16,
    origin: 24,
    dpr: 32,
    captureScale: 36,
    pad0: 40,
    pad1: 44,
    shapeCount: 48,
    blurEdge: 52,
    pad2: 56,
    pad3: 60,
    mouseSpring: 64,
    mouseVelocity: 72,
    mergeRate: 80,
    cardMergeRate: 84,
    springSizeFactor: 88,
    ballRadius: 92,
    tint: 96,
    refThickness: 112,
    refFactor: 116,
    refDispersion: 120,
    refFresnelRange: 124,
    refFresnelHardness: 128,
    refFresnelFactor: 132,
    glareRange: 136,
    glareHardness: 140,
    glareFactor: 144,
    glareConvergence: 148,
    glareOppositeFactor: 152,
    glareAngle: 156,
    roundness: 160,
    time: 164,
    shadowExpand: 168,
    shadowFactor: 172,
    shadowOffset: 176,
    size: 192,
  };

  const VERTEX = `
struct VertexOutput {
  @builtin(position) position: vec4f,
  @location(0) uv: vec2f,
};
@vertex
fn vs_main(@location(0) a_position: vec2f) -> VertexOutput {
  var out: VertexOutput;
  let uv = (a_position + 1.0) * 0.5;
  out.uv = vec2f(uv.x, 1.0 - uv.y);
  out.position = vec4f(a_position, 0.0, 1.0);
  return out;
}
`;

  const BLUR_FRAGMENT = `
struct BlurUniforms {
  resolution: vec2f,
  blurRadius: i32,
  pad: i32,
};
@group(0) @binding(0) var<uniform> u: BlurUniforms;
@group(0) @binding(1) var prevTex: texture_2d<f32>;
@group(0) @binding(2) var samp: sampler;
@group(0) @binding(3) var<storage, read> weights: array<f32, 16>;

@fragment
fn fs_main(@location(0) v_uv: vec2f) -> @location(0) vec4f {
  let texelSize = 1.0 / u.resolution;
  var color = textureSampleLevel(prevTex, samp, v_uv, 0.0) * weights[0];
  for (var i: i32 = 1; i <= u.blurRadius; i = i + 1) {
    // Mirrors the reference MAX_BLUR_RADIUS guard: never index past the
    // weights storage array, even if blurRadius were ever corrupted.
    if (i >= 16) { break; }
    let w = weights[i];
    color += textureSampleLevel(prevTex, samp, v_uv + vec2f(f32(i) * texelSize.x, 0.0), 0.0) * w;
    color += textureSampleLevel(prevTex, samp, v_uv - vec2f(f32(i) * texelSize.x, 0.0), 0.0) * w;
  }
  return color;
}
`;

  const BLUR_FRAGMENT_V = BLUR_FRAGMENT.replaceAll(
    "vec2f(f32(i) * texelSize.x, 0.0)",
    "vec2f(0.0, f32(i) * texelSize.y)"
  );

  const MAIN_FRAGMENT = `
const PI: f32 = 3.14159265359;
const N_R: f32 = 0.98;
const N_G: f32 = 1.0;
const N_B: f32 = 1.02;

struct Uniforms {
  resolution: vec2f,
  textureSize: vec2f,
  scroll: vec2f,
  origin: vec2f,
  dpr: f32,
  captureScale: f32,
  pad0: f32,
  pad1: f32,
  shapeCount: i32,
  blurEdge: i32,
  pad2: f32,
  pad3: f32,
  mouseSpring: vec2f,
  mouseVelocity: vec2f,
  mergeRate: f32,
  cardMergeRate: f32,
  springSizeFactor: f32,
  ballRadius: f32,
  tint: vec4f,
  refThickness: f32,
  refFactor: f32,
  refDispersion: f32,
  refFresnelRange: f32,
  refFresnelHardness: f32,
  refFresnelFactor: f32,
  glareRange: f32,
  glareHardness: f32,
  glareFactor: f32,
  glareConvergence: f32,
  glareOppositeFactor: f32,
  glareAngle: f32,
  roundness: f32,
  time: f32,
  shadowExpand: f32,
  shadowFactor: f32,
  shadowOffset: vec2f,
};

@group(0) @binding(0) var<uniform> u: Uniforms;
@group(0) @binding(1) var u_bg: texture_2d<f32>;
@group(0) @binding(2) var u_blurredBg: texture_2d<f32>;
@group(0) @binding(3) var u_sampler: sampler;
@group(0) @binding(4) var<storage, read> u_shapes: array<vec4f, 128>;
@group(0) @binding(5) var<storage, read> u_radii: array<f32, 128>;

const D65_WHITE: vec3f = vec3f(0.95045592705, 1.0, 1.08905775076);
const RGB_TO_XYZ_M_COL0: vec3f = vec3f(0.4124, 0.3576, 0.1805);
const RGB_TO_XYZ_M_COL1: vec3f = vec3f(0.2126, 0.7152, 0.0722);
const RGB_TO_XYZ_M_COL2: vec3f = vec3f(0.0193, 0.1192, 0.9505);
const XYZ_TO_RGB_M_COL0: vec3f = vec3f(3.2406255, -1.537208, -0.4986286);
const XYZ_TO_RGB_M_COL1: vec3f = vec3f(-0.9689307, 1.8757561, 0.0415175);
const XYZ_TO_RGB_M_COL2: vec3f = vec3f(0.0557101, -0.2040211, 1.0569959);

fn UNCOMPAND_SRGB(a: f32) -> f32 {
  if (a > 0.04045) { return pow((a + 0.055) / 1.055, 2.4); }
  return a / 12.92;
}
fn COMPAND_RGB(a: f32) -> f32 {
  if (a <= 0.0031308) { return 12.92 * a; }
  return 1.055 * pow(a, 0.41666666666) - 0.055;
}
fn SRGB_TO_RGB(srgb: vec3f) -> vec3f {
  return vec3f(UNCOMPAND_SRGB(srgb.x), UNCOMPAND_SRGB(srgb.y), UNCOMPAND_SRGB(srgb.z));
}
fn RGB_TO_SRGB(rgb: vec3f) -> vec3f {
  return vec3f(COMPAND_RGB(rgb.x), COMPAND_RGB(rgb.y), COMPAND_RGB(rgb.z));
}
fn RGB_TO_XYZ(rgb: vec3f) -> vec3f {
  return vec3f(dot(rgb, RGB_TO_XYZ_M_COL0), dot(rgb, RGB_TO_XYZ_M_COL1), dot(rgb, RGB_TO_XYZ_M_COL2));
}
fn XYZ_TO_RGB(xyz: vec3f) -> vec3f {
  return vec3f(dot(xyz, XYZ_TO_RGB_M_COL0), dot(xyz, XYZ_TO_RGB_M_COL1), dot(xyz, XYZ_TO_RGB_M_COL2));
}
fn SRGB_TO_XYZ(srgb: vec3f) -> vec3f { return RGB_TO_XYZ(SRGB_TO_RGB(srgb)); }
fn XYZ_TO_SRGB(xyz: vec3f) -> vec3f { return RGB_TO_SRGB(XYZ_TO_RGB(xyz)); }
fn XYZ_TO_LAB_F(x: f32) -> f32 {
  if (x > 0.00885645167) { return pow(x, 0.333333333); }
  return 7.78703703704 * x + 0.13793103448;
}
fn XYZ_TO_LAB(xyz: vec3f) -> vec3f {
  let s = vec3f(
    XYZ_TO_LAB_F(xyz.x / D65_WHITE.x),
    XYZ_TO_LAB_F(xyz.y / D65_WHITE.y),
    XYZ_TO_LAB_F(xyz.z / D65_WHITE.z)
  );
  return vec3f(116.0 * s.y - 16.0, 500.0 * (s.x - s.y), 200.0 * (s.y - s.z));
}
fn SRGB_TO_LAB(srgb: vec3f) -> vec3f { return XYZ_TO_LAB(SRGB_TO_XYZ(srgb)); }
fn LAB_TO_LCH(lab: vec3f) -> vec3f {
  return vec3f(lab.x, sqrt(dot(lab.yz, lab.yz)), atan2(lab.z, lab.y) * 57.2957795131);
}
fn SRGB_TO_LCH(srgb: vec3f) -> vec3f { return LAB_TO_LCH(SRGB_TO_LAB(srgb)); }
fn LAB_TO_XYZ_F(x: f32) -> f32 {
  if (x > 0.206897) { return x * x * x; }
  return 0.12841854934 * (x - 0.137931034);
}
fn LAB_TO_XYZ(lab: vec3f) -> vec3f {
  let w = (lab.x + 16.0) / 116.0;
  return D65_WHITE * vec3f(
    LAB_TO_XYZ_F(w + lab.y / 500.0),
    LAB_TO_XYZ_F(w),
    LAB_TO_XYZ_F(w - lab.z / 200.0)
  );
}
fn LAB_TO_SRGB(lab: vec3f) -> vec3f { return XYZ_TO_SRGB(LAB_TO_XYZ(lab)); }
fn LCH_TO_LAB(lch: vec3f) -> vec3f {
  return vec3f(lch.x, lch.y * cos(lch.z * 0.01745329251), lch.y * sin(lch.z * 0.01745329251));
}
fn LCH_TO_SRGB(lch: vec3f) -> vec3f { return LAB_TO_SRGB(LCH_TO_LAB(lch)); }

fn sdCircle(p: vec2f, r: f32) -> f32 { return length(p) - r; }
fn superellipseCornerSDF(p_in: vec2f, r: f32, n: f32) -> f32 {
  let p = abs(p_in);
  return pow(pow(p.x, n) + pow(p.y, n), 1.0 / n) - r;
}
fn roundedRectSDF(p_in: vec2f, center: vec2f, width: f32, height: f32, cornerRadius: f32, n: f32) -> f32 {
  let p = p_in - center;
  let cr = cornerRadius * u.dpr;
  let d = abs(p) - vec2f(width * u.dpr, height * u.dpr) * 0.5;
  if (d.x > -cr && d.y > -cr) {
    let cornerCenter = sign(p) * (vec2f(width * u.dpr, height * u.dpr) * 0.5 - vec2f(cr));
    return superellipseCornerSDF(p - cornerCenter, cr, n);
  }
  return min(max(d.x, d.y), 0.0) + length(max(d, vec2f(0.0)));
}
fn smin(a: f32, b: f32, k: f32) -> f32 {
  let h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
  return mix(b, a, h) - k * h * (1.0 - h);
}

fn mergedAt(pageCss: vec2f) -> f32 {
  let p = pageCss / u.resolution.y * u.dpr;
  var d: f32 = 1e20;
  let margin = u.ballRadius + 80.0;
  for (var i: i32 = 0; i < 128; i = i + 1) {
    if (i >= u.shapeCount) { break; }
    let s = u_shapes[i];
    if (pageCss.x < s.x - margin || pageCss.x > s.x + s.z + margin ||
        pageCss.y < s.y - margin || pageCss.y > s.y + s.w + margin) {
      continue;
    }
    let center = (s.xy + s.zw * 0.5) / u.resolution.y * u.dpr;
    let sd = roundedRectSDF(
      p,
      center,
      s.z / u.resolution.y,
      s.w / u.resolution.y,
      u_radii[i] / u.resolution.y,
      u.roundness
    );
    d = smin(d, sd, u.cardMergeRate);
  }
  let ballCenter = u.mouseSpring / u.resolution.y * u.dpr;
  let pulse = 1.0 + 0.02 * sin(u.time * 1.4);
  let stretch = clamp(length(u.mouseVelocity) * u.springSizeFactor * 0.00002, 0.0, 0.5);
  var radius = u.ballRadius * u.dpr / u.resolution.y * pulse;
  let rel = p - ballCenter;
  let dir = select(vec2f(1.0, 0.0), normalize(u.mouseVelocity), length(u.mouseVelocity) > 1e-3);
  let along = dot(rel, dir);
  let perp = dot(rel, vec2f(-dir.y, dir.x));
  let scaled = vec2f(along / (1.0 + stretch), perp * (1.0 + stretch * 0.35));
  let ball = length(scaled) - radius;
  return smin(d, ball, u.mergeRate);
}

fn getNormal(pageCss: vec2f) -> vec2f {
  let h = vec2f(1.0);
  let step = h / u.dpr;
  let grad = vec2f(
    mergedAt(pageCss + vec2f(step.x, 0.0)) - mergedAt(pageCss - vec2f(step.x, 0.0)),
    mergedAt(pageCss + vec2f(0.0, step.y)) - mergedAt(pageCss - vec2f(0.0, step.y))
  ) / (2.0 * h);
  return grad * 1414.213562;
}

fn safeAsin(x: f32) -> f32 { return asin(clamp(x, -1.0, 1.0)); }

fn vec2ToAngle(v: vec2f) -> f32 {
  var angle = atan2(v.y, v.x);
  if (angle < 0.0) { angle += 2.0 * PI; }
  return angle;
}

// Mirrors the reference safeNormalize: guard against a zero gradient (smin
// saddle points, shape symmetry centers) which would make normalize yield
// NaN. Fall back to a unit vector rather than the zero vector, because
// atan2(0, 0) is NaN in WGSL too.
fn safeNormalize(v: vec2f) -> vec2f {
  let l = length(v);
  if (l < 1e-8) { return vec2f(1.0, 0.0); }
  return v / l;
}

fn getTextureDispersion(uv: vec2f, mixRate: f32, offset: vec2f, factor: f32) -> vec4f {
  var pixel = vec4f(1.0);
  pixel.r = mix(
    textureSampleLevel(u_bg, u_sampler, uv + offset * (1.0 - (N_R - 1.0) * factor), 0.0).r,
    textureSampleLevel(u_blurredBg, u_sampler, uv + offset * (1.0 - (N_R - 1.0) * factor), 0.0).r,
    mixRate
  );
  pixel.g = mix(
    textureSampleLevel(u_bg, u_sampler, uv + offset * (1.0 - (N_G - 1.0) * factor), 0.0).g,
    textureSampleLevel(u_blurredBg, u_sampler, uv + offset * (1.0 - (N_G - 1.0) * factor), 0.0).g,
    mixRate
  );
  pixel.b = mix(
    textureSampleLevel(u_bg, u_sampler, uv + offset * (1.0 - (N_B - 1.0) * factor), 0.0).b,
    textureSampleLevel(u_blurredBg, u_sampler, uv + offset * (1.0 - (N_B - 1.0) * factor), 0.0).b,
    mixRate
  );
  return pixel;
}

@fragment
fn fs_main(@builtin(position) frag_coord: vec4f, @location(0) v_uv: vec2f) -> @location(0) vec4f {
  let viewportCss = vec2f(frag_coord.x, frag_coord.y) / u.dpr;
  let pageCss = viewportCss + u.scroll;
  let uv = (pageCss - u.origin) * u.captureScale / u.textureSize;

  let merged = mergedAt(pageCss);
  let shadow = exp(
    -1.0 / u.shadowExpand *
      abs(mergedAt(pageCss + u.shadowOffset)) *
      (u.resolution.y / u.dpr)
  ) * 0.6 * u.shadowFactor;

  var outColor: vec4f;
  if (merged < 0.005) {
    let nmerged = -1.0 * merged * (u.resolution.y / u.dpr);
    // clamp: pow(negative, 2.0) is NaN in WGSL; nmerged >= refThickness is
    // already forced to edgeFactor = 0 below, so mirror that here instead of
    // relying on the NaN being overwritten afterwards.
    let xRatio = max(0.0, 1.0 - nmerged / u.refThickness);
    let thetaI = safeAsin(pow(xRatio, 2.0));
    let thetaT = safeAsin(1.0 / u.refFactor * sin(thetaI));
    var edgeFactor = -1.0 * tan(thetaT - thetaI);
    if (nmerged >= u.refThickness) { edgeFactor = 0.0; }

    if (edgeFactor <= 0.0) {
      outColor = textureSampleLevel(u_blurredBg, u_sampler, uv, 0.0);
      outColor = mix(outColor, vec4f(u.tint.rgb, 1.0), u.tint.a * 0.8);
    } else {
      let edgeH = nmerged / u.refThickness;
      let normal = getNormal(pageCss);
      var blurMixRate: f32;
      if (u.blurEdge > 0) { blurMixRate = 1.0; } else { blurMixRate = edgeH; }
      // normal and uv are both top-down here; the reference GLSL computes
      // everything bottom-up with no flip, so do not flip Y a second time.
      let dispScreen = -normal * edgeFactor * 0.05 * u.dpr *
        vec2f(u.resolution.y / u.resolution.x, 1.0);
      let dispCss = dispScreen * (u.resolution / u.dpr);
      let offset = dispCss * u.captureScale / u.textureSize;
      let blurredPixel = getTextureDispersion(uv, blurMixRate, offset, u.refDispersion);
      outColor = mix(blurredPixel, vec4f(u.tint.rgb, 1.0), u.tint.a * 0.8);

      // The base of these powers is negative deep inside shapes; GLSL pow
      // yields a negative value that clamps to 0, while WGSL pow is IEEE
      // NaN for a negative base, which would poison the whole pixel. Guard
      // with max(0.0, ...) to match the GLSL result.
      let fresnelFactor = clamp(
        pow(
          max(
            1.0 + merged * (u.resolution.y / u.dpr) / 1500.0 *
              pow(500.0 / u.refFresnelRange, 2.0) + u.refFresnelHardness,
            0.0
          ),
          5.0
        ), 0.0, 1.0
      );
      var fresnelTintLCH = SRGB_TO_LCH(mix(vec3f(1.0), u.tint.rgb, u.tint.a * 0.5));
      fresnelTintLCH.x += 20.0 * fresnelFactor * u.refFresnelFactor;
      fresnelTintLCH.x = clamp(fresnelTintLCH.x, 0.0, 100.0);
      outColor = mix(
        outColor,
        vec4f(LCH_TO_SRGB(fresnelTintLCH), 1.0),
        fresnelFactor * u.refFresnelFactor * 0.7 * length(normal)
      );

      let glareGeoFactor = clamp(
        pow(
          max(
            1.0 + merged * (u.resolution.y / u.dpr) / 1500.0 *
              pow(500.0 / u.glareRange, 2.0) + u.glareHardness,
            0.0
          ),
          5.0
        ), 0.0, 1.0
      );
      // glare angle is computed from the bottom-up normal (like the
      // reference), so flip only the angle input; dispersion above uses the
      // top-down normal directly.
      let glareAngle = (vec2ToAngle(safeNormalize(vec2f(normal.x, -normal.y))) - PI / 4.0 + u.glareAngle) * 2.0;
      var glareFarside: i32 = 0;
      if ((glareAngle > PI * (2.0 - 0.5) && glareAngle < PI * (4.0 - 0.5)) ||
          glareAngle < PI * (0.0 - 0.5)) {
        glareFarside = 1;
      }
      var sideFactor: f32;
      if (glareFarside == 1) { sideFactor = 1.2 * u.glareOppositeFactor; } else { sideFactor = 1.2; }
      var glareAngleFactor = (0.5 + sin(glareAngle) * 0.5) * sideFactor * u.glareFactor;
      glareAngleFactor = clamp(pow(glareAngleFactor, 0.1 + u.glareConvergence * 2.0), 0.0, 1.0);

      var glareTintLCH = SRGB_TO_LCH(mix(blurredPixel.rgb, u.tint.rgb, u.tint.a * 0.5));
      glareTintLCH.x += 150.0 * glareAngleFactor * glareGeoFactor;
      glareTintLCH.y += 30.0 * glareAngleFactor * glareGeoFactor;
      glareTintLCH.x = clamp(glareTintLCH.x, 0.0, 120.0);
      outColor = mix(
        outColor,
        vec4f(LCH_TO_SRGB(glareTintLCH), 1.0),
        glareAngleFactor * glareGeoFactor * length(normal)
      );
    }
  } else {
    outColor = textureSampleLevel(u_bg, u_sampler, uv, 0.0);
  }

  outColor = mix(
    outColor,
    textureSampleLevel(u_bg, u_sampler, uv, 0.0),
    smoothstep(-0.001, 0.001, merged)
  );
  let distCss = -merged * (u.resolution.y / u.dpr);
  let interiorFade = smoothstep(0.0, 6.0, distCss);
  let alpha = mix(1.0, 0.12, interiorFade);

  var result: vec4f;
  if (merged > 0.0) {
    let t = smoothstep(0.0, 0.002, merged);
    result = vec4f(mix(outColor.rgb, vec3f(0.0), t), mix(alpha, clamp(shadow * 4.0, 0.0, 0.85), t));
  } else {
    result = vec4f(outColor.rgb, alpha);
  }
  return vec4f(result.rgb * result.a, result.a);
}
`;

  let device = null;
  let context = null;
  let format = null;
  let mainPipeline = null;
  let hblurPipeline = null;
  let vblurPipeline = null;
  let sampler = null;
  let uniformBuffer = null;
  let blurUniformBuffer = null;
  let weightsBuffer = null;
  let shapesBuffer = null;
  let radiiBuffer = null;
  let vertexBuffer = null;
  let mainBindGroup = null;
  let hblurBindGroup = null;
  let vblurBindGroup = null;
  let bgTexture = null;
  let blurredTexture = null;
  let hblurTexture = null;
  let textureSize = { width: 0, height: 0 };
  let state = null;
  let canvas = null;
  let initialized = false;
  let blurWeights = [0.9783, 0.01085];

  const gaussianWeights = (radius) => {
    const sigma = radius / 3.0;
    const kernel = [];
    let sum = 0;
    for (let i = 0; i <= radius; i++) {
      const w = Math.exp((-0.5 * i * i) / (sigma * sigma));
      kernel.push(w);
      sum += i === 0 ? w : w * 2;
    }
    return kernel.map((w) => w / sum);
  };

  const createTexture = (width, height, usage, label) =>
    device.createTexture({
      size: { width, height },
      format: "rgba8unorm",
      usage,
      label,
    });

  const resizeTargetTextures = (width, height) => {
    const w = Math.max(2, width);
    const h = Math.max(2, height);
    if (textureSize.width === w && textureSize.height === h && bgTexture) return;
    textureSize = { width: w, height: h };
    if (bgTexture) bgTexture.destroy();
    if (blurredTexture) blurredTexture.destroy();
    if (hblurTexture) hblurTexture.destroy();
    // Correct WebGPU usage flags: COPY_DST=2, TEXTURE_BINDING=4,
    // RENDER_ATTACHMENT=16. bg is only uploaded/sampled, but Dawn's
    // copyExternalImageToTexture on macOS copies through a render pass and
    // validates the destination for RENDER_ATTACHMENT as well as COPY_DST.
    const blurUsage =
      GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING;
    bgTexture = createTexture(
      w,
      h,
      GPUTextureUsage.RENDER_ATTACHMENT |
        GPUTextureUsage.TEXTURE_BINDING |
        GPUTextureUsage.COPY_DST,
      "homepage-bg"
    );
    blurredTexture = createTexture(w, h, blurUsage, "homepage-blurred");
    hblurTexture = createTexture(w, h, blurUsage, "homepage-hblur");
  };

  const uploadTexture = (target, source) => {
    device.queue.copyExternalImageToTexture(
      { source },
      { texture: target },
      { width: source.width, height: source.height }
    );
  };

  const createBindGroup = (layout, bindings) => {
    const entries = [];
    for (const key of Object.keys(bindings)) {
      entries.push({
        binding: Number(key),
        resource: bindings[key],
      });
    }
    return device.createBindGroup({ layout, entries });
  };

  const init = async (targetCanvas, glassState) => {
    if (!navigator.gpu) return false;
    canvas = targetCanvas;
    state = glassState;
    blurWeights = gaussianWeights(1);
    const adapter = await navigator.gpu.requestAdapter();
    if (!adapter) return false;
    device = await adapter.requestDevice();
    context = canvas.getContext("webgpu");
    if (!context) return false;
    format = navigator.gpu.getPreferredCanvasFormat();
    context.configure({
      device,
      format,
      alphaMode: "premultiplied",
    });

    const mainModule = device.createShaderModule({ code: MAIN_FRAGMENT, label: "homepage-main" });
    const blurModuleH = device.createShaderModule({ code: VERTEX + BLUR_FRAGMENT, label: "homepage-blur-h" });
    const blurModuleV = device.createShaderModule({ code: VERTEX + BLUR_FRAGMENT_V, label: "homepage-blur-v" });
    const vertexModule = device.createShaderModule({ code: VERTEX, label: "homepage-vs" });

    sampler = device.createSampler({
      magFilter: "linear",
      minFilter: "linear",
      addressModeU: "clamp-to-edge",
      addressModeV: "clamp-to-edge",
    });

    uniformBuffer = device.createBuffer({
      size: UNIFORM_OFFSETS.size,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    blurUniformBuffer = device.createBuffer({
      size: 16,
      usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
    });
    weightsBuffer = device.createBuffer({
      size: 16 * 4,
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });
    shapesBuffer = device.createBuffer({
      size: MAX_SHAPES * 16,
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });
    radiiBuffer = device.createBuffer({
      size: MAX_SHAPES * 4,
      usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_DST,
    });
    vertexBuffer = device.createBuffer({
      size: 6 * 2 * 4,
      usage: GPUBufferUsage.VERTEX,
      mappedAtCreation: true,
    });
    new Float32Array(vertexBuffer.getMappedRange()).set([
      -1, -1, 3, -1, -1, 3,
    ]);
    vertexBuffer.unmap();
    device.queue.writeBuffer(weightsBuffer, 0, new Float32Array(blurWeights));

    const mainLayout = device.createBindGroupLayout({
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: {} },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, texture: {} },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, sampler: {} },
        { binding: 4, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" } },
        { binding: 5, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" } },
      ],
    });
    const blurLayout = device.createBindGroupLayout({
      entries: [
        { binding: 0, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "uniform" } },
        { binding: 1, visibility: GPUShaderStage.FRAGMENT, texture: {} },
        { binding: 2, visibility: GPUShaderStage.FRAGMENT, sampler: {} },
        { binding: 3, visibility: GPUShaderStage.FRAGMENT, buffer: { type: "read-only-storage" } },
      ],
    });

    mainPipeline = device.createRenderPipeline({
      layout: device.createPipelineLayout({ bindGroupLayouts: [mainLayout] }),
      vertex: { module: vertexModule, entryPoint: "vs_main", buffers: [{ arrayStride: 8, attributes: [{ shaderLocation: 0, offset: 0, format: "float32x2" }] }] },
      fragment: {
        module: mainModule,
        entryPoint: "fs_main",
        targets: [{ format, blend: { color: { srcFactor: "one", dstFactor: "one-minus-src-alpha" }, alpha: { srcFactor: "one", dstFactor: "one-minus-src-alpha" } } }],
      },
      primitive: { topology: "triangle-list" },
    });
    const blurTarget = { format: "rgba8unorm", blend: undefined };
    hblurPipeline = device.createRenderPipeline({
      layout: device.createPipelineLayout({ bindGroupLayouts: [blurLayout] }),
      vertex: { module: vertexModule, entryPoint: "vs_main", buffers: [{ arrayStride: 8, attributes: [{ shaderLocation: 0, offset: 0, format: "float32x2" }] }] },
      fragment: { module: blurModuleH, entryPoint: "fs_main", targets: [blurTarget] },
      primitive: { topology: "triangle-list" },
    });
    vblurPipeline = device.createRenderPipeline({
      layout: device.createPipelineLayout({ bindGroupLayouts: [blurLayout] }),
      vertex: { module: vertexModule, entryPoint: "vs_main", buffers: [{ arrayStride: 8, attributes: [{ shaderLocation: 0, offset: 0, format: "float32x2" }] }] },
      fragment: { module: blurModuleV, entryPoint: "fs_main", targets: [blurTarget] },
      primitive: { topology: "triangle-list" },
    });

    initialized = true;
    return true;
  };

  const setTextures = (bgSource) => {
    if (!initialized) return;
    resizeTargetTextures(bgSource.width, bgSource.height);
    uploadTexture(bgTexture, bgSource);
    mainBindGroup = createBindGroup(mainPipeline.getBindGroupLayout(0), {
      0: uniformBuffer,
      1: bgTexture.createView(),
      2: blurredTexture.createView(),
      3: sampler,
      4: shapesBuffer,
      5: radiiBuffer,
    });
    hblurBindGroup = createBindGroup(hblurPipeline.getBindGroupLayout(0), {
      0: blurUniformBuffer,
      1: bgTexture.createView(),
      2: sampler,
      3: weightsBuffer,
    });
    vblurBindGroup = createBindGroup(vblurPipeline.getBindGroupLayout(0), {
      0: blurUniformBuffer,
      1: hblurTexture.createView(),
      2: sampler,
      3: weightsBuffer,
    });
  };

  const writeUniforms = (data) => {
    const view = new DataView(data.buffer, data.byteOffset, data.byteLength);
    const f32 = new Float32Array(data.buffer, data.byteOffset, data.byteLength / 4);
    const setF = (offset, value) => f32[offset / 4] = value;
    setF(UNIFORM_OFFSETS.resolution, state.resolution[0]);
    setF(UNIFORM_OFFSETS.resolution + 4, state.resolution[1]);
    setF(UNIFORM_OFFSETS.textureSize, textureSize.width);
    setF(UNIFORM_OFFSETS.textureSize + 4, textureSize.height);
    setF(UNIFORM_OFFSETS.scroll, state.scroll[0]);
    setF(UNIFORM_OFFSETS.scroll + 4, state.scroll[1]);
    setF(UNIFORM_OFFSETS.origin, state.origin[0]);
    setF(UNIFORM_OFFSETS.origin + 4, state.origin[1]);
    setF(UNIFORM_OFFSETS.dpr, state.dpr);
    setF(UNIFORM_OFFSETS.captureScale, state.captureScale);
    view.setInt32(UNIFORM_OFFSETS.shapeCount, state.shapeCount, true);
    view.setInt32(UNIFORM_OFFSETS.blurEdge, 1, true);
    setF(UNIFORM_OFFSETS.mouseSpring, state.mouseSpring[0]);
    setF(UNIFORM_OFFSETS.mouseSpring + 4, state.mouseSpring[1]);
    setF(UNIFORM_OFFSETS.mouseVelocity, state.mouseVelocity[0]);
    setF(UNIFORM_OFFSETS.mouseVelocity + 4, state.mouseVelocity[1]);
    setF(UNIFORM_OFFSETS.mergeRate, state.mergeRate);
    setF(UNIFORM_OFFSETS.cardMergeRate, state.cardMergeRate);
    setF(UNIFORM_OFFSETS.springSizeFactor, state.springSizeFactor);
    setF(UNIFORM_OFFSETS.ballRadius, state.ballRadius);
    setF(UNIFORM_OFFSETS.tint, 1);
    setF(UNIFORM_OFFSETS.tint + 4, 1);
    setF(UNIFORM_OFFSETS.tint + 8, 1);
    setF(UNIFORM_OFFSETS.tint + 12, 0);
    setF(UNIFORM_OFFSETS.refThickness, state.refThickness);
    setF(UNIFORM_OFFSETS.refFactor, state.refFactor);
    setF(UNIFORM_OFFSETS.refDispersion, state.refDispersion);
    setF(UNIFORM_OFFSETS.refFresnelRange, state.refFresnelRange);
    setF(UNIFORM_OFFSETS.refFresnelHardness, state.refFresnelHardness);
    setF(UNIFORM_OFFSETS.refFresnelFactor, state.refFresnelFactor);
    setF(UNIFORM_OFFSETS.glareRange, state.glareRange);
    setF(UNIFORM_OFFSETS.glareHardness, state.glareHardness);
    setF(UNIFORM_OFFSETS.glareFactor, state.glareFactor);
    setF(UNIFORM_OFFSETS.glareConvergence, state.glareConvergence);
    setF(UNIFORM_OFFSETS.glareOppositeFactor, state.glareOppositeFactor);
    setF(UNIFORM_OFFSETS.glareAngle, state.glareAngle);
    setF(UNIFORM_OFFSETS.roundness, state.roundness);
    setF(UNIFORM_OFFSETS.time, state.time);
    setF(UNIFORM_OFFSETS.shadowExpand, state.shadowExpand);
    setF(UNIFORM_OFFSETS.shadowFactor, state.shadowFactor);
    setF(UNIFORM_OFFSETS.shadowOffset, state.shadowOffset[0]);
    setF(UNIFORM_OFFSETS.shadowOffset + 4, state.shadowOffset[1]);
    device.queue.writeBuffer(uniformBuffer, 0, data);
  };

  const render = () => {
    if (!initialized || !mainBindGroup || !hblurBindGroup || !vblurBindGroup) return;
    const width = Math.round(window.innerWidth * state.dpr);
    const height = Math.round(window.innerHeight * state.dpr);
    if (canvas.width !== width || canvas.height !== height) {
      canvas.width = width;
      canvas.height = height;
      canvas.style.width = window.innerWidth + "px";
      canvas.style.height = window.innerHeight + "px";
    }
    state.resolution = [width, height];
    state.time = (performance.now() - state.startTime) / 1000;
    const uniforms = new Float32Array(UNIFORM_OFFSETS.size / 4);
    writeUniforms(uniforms);

    if (state.shapeCount > 0 && state.shapes && state.radii) {
      // shapeArray/radiusArray are recreated exactly shapeCount-sized on every
      // refresh, so write the whole array. Explicit byte sizes are avoided:
      // some Chrome builds validate writeBuffer's dataOffset/size against the
      // typed array element count instead of byte length, and the full-array
      // form is correct under either interpretation.
      device.queue.writeBuffer(shapesBuffer, 0, state.shapes);
      device.queue.writeBuffer(radiiBuffer, 0, state.radii);
    }

    // blurRadius is an i32 field in WGSL; writing it as f32 would reinterpret
    // 1.0f (0x3F800000) as 1065353216 and hang the blur loop for ~1e9
    // iterations per pixel. Write the int with a DataView.
    const blurUniforms = new DataView(new ArrayBuffer(16));
    blurUniforms.setFloat32(0, textureSize.width, true);
    blurUniforms.setFloat32(4, textureSize.height, true);
    blurUniforms.setInt32(8, 1, true);
    device.queue.writeBuffer(blurUniformBuffer, 0, blurUniforms);

    const encoder = device.createCommandEncoder();

    const blurPass = (pipeline, target, bindGroup) => {
      const pass = encoder.beginRenderPass({
        colorAttachments: [{
          view: target.createView(),
          loadOp: "clear",
          storeOp: "store",
        }],
      });
      pass.setPipeline(pipeline);
      pass.setBindGroup(0, bindGroup);
      pass.setVertexBuffer(0, vertexBuffer);
      pass.draw(3, 1, 0, 0);
      pass.end();
    };

    blurPass(hblurPipeline, hblurTexture, hblurBindGroup);
    blurPass(vblurPipeline, blurredTexture, vblurBindGroup);

    const currentTexture = context.getCurrentTexture();
    const pass = encoder.beginRenderPass({
      colorAttachments: [{
        view: currentTexture.createView(),
        loadOp: "clear",
        storeOp: "store",
        clearValue: { r: 0, g: 0, b: 0, a: 0 },
      }],
    });
    pass.setPipeline(mainPipeline);
    pass.setBindGroup(0, mainBindGroup);
    pass.setVertexBuffer(0, vertexBuffer);
    pass.draw(3, 1, 0, 0);
    pass.end();
    device.queue.submit([encoder.finish()]);
  };

  const destroy = () => {
    if (bgTexture) bgTexture.destroy();
    if (blurredTexture) blurredTexture.destroy();
    if (hblurTexture) hblurTexture.destroy();
    initialized = false;
  };

  window.HomepageGlassWebGPU = {
    init,
    setTextures,
    render,
    destroy,
    get device() {
      return device;
    },
  };
})();
