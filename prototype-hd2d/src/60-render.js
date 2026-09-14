// =====================================================================
// 光与后期：单一暖光从左上来，阴影偏紫；后期是 HD-2D 的招牌（移轴景深、泛光、调色）
// 微信官方不建议小游戏做后处理，所以画质分三档，低档完全不开后期
// =====================================================================
let renderer, scene, camera, composer, sun, hemi, amb;
const PASS = {}, PL = [], camTarget = new THREE.Vector3();
const QUALS = {
  low: { pr: 1, shadow: 1024, soft: false, post: false, lights: 2, blur: 0 },
  mid: { pr: Math.min(devicePixelRatio, 1.5), shadow: 1024, soft: true, post: true, lights: 4, blur: 3 },
  high: { pr: Math.min(devicePixelRatio, 2), shadow: 2048, soft: true, post: true, lights: 6, blur: 3.6 },
};
const GradeShader = {
  uniforms: { tDiffuse: { value: null }, uSat: { value: 1.12 }, uShadow: { value: new THREE.Color('#3a2350') }, uHigh: { value: new THREE.Color('#fff0dc') }, uVig: { value: 0.34 } },
  vertexShader: 'varying vec2 vUv; void main(){ vUv = uv; gl_Position = projectionMatrix * modelViewMatrix * vec4(position, 1.0); }',
  fragmentShader: `uniform sampler2D tDiffuse; uniform float uSat; uniform vec3 uShadow; uniform vec3 uHigh; uniform float uVig; varying vec2 vUv;
    void main(){ vec4 c = texture2D(tDiffuse, vUv); float l = dot(c.rgb, vec3(0.2126, 0.7152, 0.0722));
      c.rgb = mix(vec3(l), c.rgb, uSat);
      c.rgb += uShadow * (1.0 - smoothstep(0.0, 0.28, l)) * 0.3;
      c.rgb *= mix(vec3(1.0), uHigh, smoothstep(0.35, 1.2, l));
      vec2 d = vUv - 0.5; d.x *= 0.8; c.rgb *= 1.0 - uVig * smoothstep(0.3, 0.8, length(d));
      gl_FragColor = c; }`,
};
// 天色关键帧：几点钟 → 光色、强度、太阳高度、天光、雾、灯笼亮度
const TOD = [
  [0, '#9fb0e0', 0.62, 55, '#3a4678', '#241c36', 0.85, '#18223f', 1],
  [4.8, '#9fb0e0', 0.62, 55, '#3a4678', '#241c36', 0.85, '#18223f', 1],
  [6.2, '#ffb38a', 1.3, 20, '#c9a9cf', '#4a3a5a', 0.6, '#dcb3a9', 0.35],
  [8.5, '#ffe8c8', 2.4, 40, '#cfe0ff', '#6a5a78', 0.72, '#dde5ec', 0],
  [12.5, '#fff4e2', 2.7, 58, '#d8e8ff', '#72637f', 0.76, '#e4eaee', 0],
  [16.5, '#ffd89c', 2.5, 36, '#f0dcc2', '#6f5a6a', 0.72, '#ecd7b8', 0],
  [18.2, '#ff9357', 1.7, 15, '#f3a27c', '#503052', 0.56, '#e39478', 0.7],
  [19.3, '#8c7cc4', 0.75, 12, '#4a4388', '#2a1f3c', 0.7, '#2e2a58', 1],
  [21, '#9fb0e0', 0.62, 55, '#3a4678', '#241c36', 0.85, '#18223f', 1],
  [24, '#9fb0e0', 0.62, 55, '#3a4678', '#241c36', 0.85, '#18223f', 1],
];
const LIGHT_SPOTS = [[39, 18.4, 1.7], [-13, 35.4, 2.8], [0, 0, 1.3], [-27, 21.3, 1.9], [7, 21.3, 1.9], [-38, 16.3, 1.9], [24, 16.3, 1.9], [0, 103.2, 2.6],
  [0, 109.6, 2.3], [-60, -40.4, 2.4], [-60, -33, 2.3], [39, -33, 2.3], [0, 79, 2.3], [9, -29.6, 1.7], [-16, 46.4, 2.3], [-33, -29.6, 1.7], [-10, -16.3, 1.9], [10, -16.3, 1.9]];

function setupRender(canvas) {
  renderer = new THREE.WebGLRenderer({ canvas, antialias: false, powerPreference: 'high-performance' });
  renderer.shadowMap.enabled = true; renderer.toneMapping = THREE.ACESFilmicToneMapping; renderer.info.autoReset = false;
  scene = new THREE.Scene(); scene.fog = new THREE.Fog('#dde5ec', 50, 160); scene.background = new THREE.Color('#dde5ec');
  camera = new THREE.PerspectiveCamera(40, 9 / 16, 0.5, 260);
  sun = new THREE.DirectionalLight('#fff4e2', 2.5); sun.castShadow = true; Object.assign(sun.shadow, { bias: -0.0004, normalBias: 0.03 });
  Object.assign(sun.shadow.camera, { near: 1, far: 150, left: -26, right: 26, top: 26, bottom: -26 }); scene.add(sun, sun.target);
  hemi = new THREE.HemisphereLight('#d8e8ff', '#72637f', 0.75); amb = new THREE.AmbientLight('#ffffff', 0.06); scene.add(hemi, amb);
  for (let i = 0; i < 6; i++) { const l = new THREE.PointLight('#ffb070', 0, 13, 2); scene.add(l); PL.push(l); }
  composer = new EffectComposer(renderer);
  PASS.render = new RenderPass(scene, camera);
  PASS.bloom = new UnrealBloomPass(new THREE.Vector2(256, 256), 0.4, 0.55, 0.9);
  PASS.th = new ShaderPass(HorizontalTiltShiftShader); PASS.tv = new ShaderPass(VerticalTiltShiftShader);
  PASS.th.uniforms.r.value = PASS.tv.uniforms.r.value = 0.5;
  PASS.grade = new ShaderPass(GradeShader); PASS.out = new OutputPass();
  [PASS.render, PASS.bloom, PASS.th, PASS.tv, PASS.grade, PASS.out].forEach(p => composer.addPass(p));
}
function applyQuality() {
  const q = QUALS[S.quality];
  renderer.shadowMap.type = q.soft ? THREE.PCFSoftShadowMap : THREE.PCFShadowMap;
  sun.shadow.mapSize.set(q.shadow, q.shadow); if (sun.shadow.map) { sun.shadow.map.dispose(); sun.shadow.map = null; }
  PL.forEach((l, i) => l.visible = i < q.lights);
  resize();
}
function resize() {
  const q = QUALS[S.quality], el = renderer.domElement.parentElement, w = el.clientWidth, h = el.clientHeight;
  renderer.setPixelRatio(q.pr); renderer.setSize(w, h, false);
  camera.aspect = w / h; camera.updateProjectionMatrix();
  composer.setPixelRatio(q.pr); composer.setSize(w, h);
  PASS.th.uniforms.h.value = q.blur / (w * q.pr); PASS.tv.uniforms.v.value = q.blur / (h * q.pr);
}
const _c1 = new THREE.Color(), _c2 = new THREE.Color();
function lerpHex(a, b, k, out) { return out.set(a).lerp(_c2.set(b), k); }
let NIGHT = 0;
function applyTime(h) {
  let i = 0; while (i < TOD.length - 2 && TOD[i + 1][0] <= h) i++;
  const A = TOD[i], Bk = TOD[i + 1], k = Math.min(1, Math.max(0, (h - A[0]) / (Bk[0] - A[0])));
  const L = (a, b) => a + (b - a) * k;
  lerpHex(A[1], Bk[1], k, sun.color); sun.intensity = L(A[2], Bk[2]);
  const el = L(A[3], Bk[3]) * Math.PI / 180; SUN_DIR.set(-0.84 * Math.cos(el), Math.sin(el), 0.54 * Math.cos(el)).normalize();
  lerpHex(A[4], Bk[4], k, hemi.color); lerpHex(A[5], Bk[5], k, hemi.groundColor); hemi.intensity = L(A[6], Bk[6]);
  lerpHex(A[7], Bk[7], k, scene.fog.color); scene.background.copy(scene.fog.color);
  NIGHT = L(A[8], Bk[8]);
  MAT('lantern').emissiveIntensity = 0.25 + NIGHT * 2.8;
  REFS.fadeGroups.forEach(g => g.mats.forEach(m => { if (m.userData.key === 'lantern') m.emissiveIntensity = 0.25 + NIGHT * 2.8; }));
  SIGN_MATS.forEach(m => m.emissiveIntensity = 0.1 + NIGHT * 0.45);
  SPRITE_MAT.emissiveIntensity = 0.06 + NIGHT * 0.2;
  REFS.lampMat.on.emissiveIntensity = 0.9 + NIGHT * 2.6;
  REFS.water.material.color.copy(lerpHex('#ffffff', '#7482b4', NIGHT, _c1)); REFS.sparkle.material.opacity = 0.55 - NIGHT * 0.3;
  const m = REFS.motes.material.uniforms; m.uColor.value.set(NIGHT > 0.5 ? '#d8ff7a' : '#fff2c8'); m.uAlpha.value = S.reduced ? 0 : (0.25 + NIGHT * 0.7); m.uSize.value = 20 + NIGHT * 16;
  PASS.bloom.strength = 0.32 + NIGHT * 0.65; PASS.bloom.threshold = 0.92 - NIGHT * 0.4;
  GradeShader.uniforms.uShadow.value.set(NIGHT > 0.5 ? '#1c2450' : '#3a2350');
  PASS.grade.uniforms.uShadow.value.copy(GradeShader.uniforms.uShadow.value);
  renderer.toneMappingExposure = 1.0 + NIGHT * 0.1;
  const tour = isNightTour(h); REFS.boats.forEach(b => b.g.visible = tour);
}
const SUN_DIR = new THREE.Vector3(-0.6, 0.7, 0.4);
let lightTick = 0;
function updateLights(dt) {
  lightTick -= dt; if (lightTick > 0) return; lightTick = 0.3;
  const q = QUALS[S.quality];
  const near = LIGHT_SPOTS.map(([t, s, y]) => ({ t, s, y, d: Math.hypot(t - PLAYER.t, (s - PLAYER.s) * 0.8) })).sort((a, b) => a.d - b.d).slice(0, q.lights);
  near.forEach((sp, i) => { const w = toWorld(sp.t, sp.s), l = PL[i]; l.position.set(w.x, sp.y, w.z);
    const bridge = sp.t === 0 && sp.s === 0; l.color.set(bridge ? '#ffd27a' : '#ff9a5a'); l.intensity = NIGHT * (bridge ? 3 + S.lamps * 1.2 : 16); l.distance = bridge ? 20 : 12; });
}
function updateCamera(dt) {
  const w = toWorld(PLAYER.t, PLAYER.s); _v.set(w.x, groundY(PLAYER.t, PLAYER.s) + 0.9, w.z);
  camTarget.lerp(_v, 1 - Math.exp(-dt * (S.reduced ? 20 : 6)));
  const z = S.zoom, pitch = (48 + (z - 20) / 32 * 10) * Math.PI / 180;
  camera.position.set(camTarget.x, camTarget.y + z * Math.sin(pitch), camTarget.z + z * Math.cos(pitch)); camera.lookAt(camTarget);
  scene.fog.near = z * 1.35; scene.fog.far = z * 4.6;
  sun.target.position.set(camTarget.x, 0, camTarget.z - 8); sun.position.copy(sun.target.position).addScaledVector(SUN_DIR, 80);
}
function renderFrame() {
  renderer.info.reset();
  if (QUALS[S.quality].post) composer.render(); else renderer.render(scene, camera);
}
