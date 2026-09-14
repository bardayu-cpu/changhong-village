// =====================================================================
// 搭建工具：静物按材质分桶合并（Draw Call 目标 < 200）
// 河框架坐标：x = t，z = -s，y 向上。房子正面一律朝 -s（朝镜头）
// =====================================================================
let TEX = null, ATLAS = null;
const COLL = [];                                   // 碰撞：河框架里的矩形
const addColl = (t0, t1, s0, s1) => COLL.push({ t0: Math.min(t0, t1), t1: Math.max(t0, t1), s0: Math.min(s0, s1), s1: Math.max(s0, s1) });
const MATS = new Map();
const SIGN_MATS = [];
function MAT(key) {
  if (MATS.has(key)) return MATS.get(key);
  let m;
  const std = (map, extra = {}) => new THREE.MeshStandardMaterial({ map, vertexColors: true, roughness: 0.92, metalness: 0, ...extra });
  if (key.startsWith('facade:')) { const [kind, w, h] = key.slice(7).split('|'); m = std(facadeTex(kind, +w, +h)); }
  else if (key.startsWith('awning:')) { const [a, b] = key.slice(7).split('|'); m = std(awningTex(a, b)); }
  else if (key === 'lantern') m = new THREE.MeshStandardMaterial({ color: '#c73a2c', emissive: '#ff6a2a', emissiveIntensity: 0.2, roughness: 0.6, vertexColors: true });
  else if (key === 'plain') m = new THREE.MeshStandardMaterial({ vertexColors: true, roughness: 0.85 });
  else if (key === 'leaf') m = std(TEX.leaf, { roughness: 1 });
  else if (key === 'side2') m = std(TEX.side, { side: THREE.DoubleSide });
  else m = std(TEX[key]);
  MATS.set(key, m); return m;
}

const _q = new THREE.Quaternion(), _e = new THREE.Euler(), _v = new THREE.Vector3(), _sc = new THREE.Vector3();
function M(x, y, z, ry = 0, rx = 0, rz = 0, sx = 1, sy = 1, sz = 1) {
  _e.set(rx, ry, rz, 'YXZ'); _q.setFromEuler(_e);
  return new THREE.Matrix4().compose(_v.set(x, y, z), _q, _sc.set(sx, sy, sz));
}
function boxG(w, h, d, unit = 2) { // UV 按真实尺寸重复，贴图不拉伸
  const g = new THREE.BoxGeometry(w, h, d), uv = g.attributes.uv, dims = [[d, h], [d, h], [w, d], [w, d], [w, h], [w, h]];
  for (let i = 0; i < uv.count; i++) { const f = Math.floor(i / 4); uv.setXY(i, uv.getX(i) * dims[f][0] / unit, uv.getY(i) * dims[f][1] / unit); }
  return g;
}
function triG(half, r) { // 山墙三角
  const g = new THREE.BufferGeometry();
  g.setAttribute('position', new THREE.Float32BufferAttribute([0, 0, half, 0, 0, -half, 0, r, 0, 0, 0, -half, 0, 0, half, 0, r, 0], 3));
  g.setAttribute('normal', new THREE.Float32BufferAttribute([1, 0, 0, 1, 0, 0, 1, 0, 0, -1, 0, 0, -1, 0, 0, -1, 0, 0], 3));
  g.setAttribute('uv', new THREE.Float32BufferAttribute([half, 0, 0, 0, half / 2, r / 2, 0, 0, half, 0, half / 2, r / 2], 2));
  return g;
}
class Builder {
  constructor() { this.b = new Map(); }
  add(key, geo, m, color) {
    const g = geo.index ? geo.toNonIndexed() : geo.clone();
    if (m) g.applyMatrix4(m);
    const n = g.attributes.position.count, c = new THREE.Color(color || '#ffffff'), a = new Float32Array(n * 3);
    for (let i = 0; i < n; i++) { a[i * 3] = c.r; a[i * 3 + 1] = c.g; a[i * 3 + 2] = c.b; }
    g.setAttribute('color', new THREE.BufferAttribute(a, 3));
    for (const k of Object.keys(g.attributes)) if (!['position', 'normal', 'uv', 'color'].includes(k)) g.deleteAttribute(k);
    if (!this.b.has(key)) this.b.set(key, []); this.b.get(key).push(g);
  }
  flush(parent, { cast = true, receive = true, mat, clone = false } = {}) {
    const out = [];
    for (const [key, list] of this.b) {
      let mt = mat || MAT(key); if (clone) { mt = mt.clone(); mt.userData.key = key; }
      const mesh = new THREE.Mesh(mergeGeometries(list, false), mt);
      mesh.castShadow = cast; mesh.receiveShadow = receive; parent.add(mesh); out.push(mesh);
      list.forEach(g => g.dispose());
    }
    this.b.clear(); return out;
  }
}

// ---------- 招牌（每块独立网格，夜里微微发亮） ----------
function addSign(parent, text, t, y, s, hgt = 0.62, opts = {}) {
  const { tex, w, h } = signTexture(text, opts), wid = hgt * w / h;
  const m = new THREE.MeshStandardMaterial({ map: tex, emissiveMap: tex, emissive: '#ffffff', emissiveIntensity: 0.12, roughness: 0.8 });
  SIGN_MATS.push(m);
  const mesh = new THREE.Mesh(new THREE.PlaneGeometry(wid, hgt), m); mesh.position.set(t, y, -s); mesh.rotation.x = -0.38; mesh.castShadow = true; parent.add(mesh); return mesh;
}

// ---------- 屋顶：小青瓦双坡，脊两头微翘 ----------
function roof(B, x, zc, w, d, yTop, key = 'tile', riseK = 0.34, oz = 0.8) {
  const ox = 0.45, half = d / 2, r = d * riseK, a = half + oz, ang = Math.atan2(r, half), L = a / Math.cos(ang), th = 0.16, yr = yTop + r;
  const yMid = yr - (a / 2) * Math.tan(ang) + th / 2;
  B.add(key, boxG(w + 2 * ox, th, L, 1.2), M(x, yMid, zc + a / 2, 0, ang));
  B.add(key, boxG(w + 2 * ox, th, L, 1.2), M(x, yMid, zc - a / 2, 0, -ang));
  B.add('side', triG(half, r), M(x - w / 2, yTop, zc)); B.add('side', triG(half, r), M(x + w / 2, yTop, zc));
  B.add(key, boxG(w + 2 * ox + 0.3, 0.22, 0.28, 1.2), M(x, yr + 0.09, zc), '#bcbac6');
  for (const sg of [-1, 1]) B.add(key, boxG(0.55, 0.16, 0.28, 1.2), M(x + sg * (w / 2 + ox + 0.3), yr + 0.22, zc, 0, 0, -sg * 0.5), '#bcbac6');
}
function lantern(B, x, y, z, big = 1) {
  B.add('lantern', new THREE.CylinderGeometry(0.17 * big, 0.17 * big, 0.32 * big, 8), M(x, y, z));
  B.add('plain', new THREE.CylinderGeometry(0.11 * big, 0.11 * big, 0.05, 8), M(x, y + 0.18 * big, z), P.gold);
  B.add('plain', new THREE.CylinderGeometry(0.11 * big, 0.11 * big, 0.05, 8), M(x, y - 0.18 * big, z), P.gold);
  B.add('plain', boxG(0.03, 0.3, 0.03), M(x, y + 0.36 * big, z), P.ink);
}
// 房子。s 是正面所在位置，身子往北（+s）长
function house(B, o) {
  const x = o.t, zf = -o.s, zc = zf - o.d / 2, base = 0.28;
  B.add('slab', boxG(o.w + 0.3, base, o.d + 0.3, 1.5), M(x, base / 2, zc), '#cfc8cc');
  B.add(o.side || 'side', boxG(o.w, o.h, o.d, 2), M(x, base + o.h / 2, zc));
  B.add(`facade:${o.facade}|${o.w}|${o.h}`, new THREE.PlaneGeometry(o.w, o.h), M(x, base + o.h / 2, zf + 0.012));
  if (o.flat) { B.add('slab', boxG(o.w + 0.2, 0.3, o.d + 0.2, 1.5), M(x, base + o.h + 0.15, zc), '#d9d4cf'); }
  else roof(B, x, zc, o.w, o.d, base + o.h, o.roofKey || 'tile', o.rise || 0.34);
  const ey = base + o.h * 0.44 + 0.12;
  if (o.eave) { B.add(o.roofKey || 'tile', boxG(o.w + 0.3, 0.09, 1.05, 1.2), M(x, ey, zf + 0.48, 0, 0.38)); B.add('wood', boxG(o.w + 0.3, 0.1, 0.08, 1), M(x, ey - 0.2, zf + 0.96)); }
  for (let k = 0; k < (o.lanterns || 0); k++) { const lx = x + (k % 2 ? 1 : -1) * o.w * (k < 2 ? 0.3 : 0.12); lantern(B, lx, (o.eave ? ey - 0.62 : base + o.h * 0.82), zf + (o.eave ? 0.78 : 0.3)); }
  addColl(o.t - o.w / 2 - 0.2, o.t + o.w / 2 + 0.2, o.s - 0.2, o.s + o.d + 0.2);
  return { signY: o.eave ? ey + 0.06 : base + o.h * 0.84, signZ: o.eave ? -(zf + 1.0) : -(zf + 0.03) };
}
function leafCol(pal) { const c = pal[Math.floor(rnd() * pal.length)]; return c; }
const LEAVES = ['#80b457', '#6aa04b', '#8fc265', '#5c8f45', '#9ac36a'];
const LEAVES_HERO = ['#a6cf66', '#8fbf57', '#b8d876', '#79a84c', '#c4dd84'];
function tree(B, t, s, sc = 1) {
  const x = t, z = -s, h = rr(1.5, 2.3) * sc;
  B.add('bark', new THREE.CylinderGeometry(0.15 * sc, 0.25 * sc, h, 6), M(x, h / 2, z));
  const n = 3 + Math.floor(rnd() * 3);
  for (let i = 0; i < n; i++) { const a = rnd() * 6.28, rad = rr(0.1, 0.85) * sc, sz = rr(0.85, 1.45) * sc;
    B.add('leaf', new THREE.IcosahedronGeometry(sz, 1), M(x + Math.cos(a) * rad, h + rr(0.2, 1.1) * sc, z + Math.sin(a) * rad, rnd() * 3, 0, 0, 1, 0.8, 1), leafCol(LEAVES)); }
  addColl(t - 0.35 * sc, t + 0.35 * sc, s - 0.35 * sc, s + 0.35 * sc);
}
function bamboo(B, t, s) {
  for (let i = 0; i < 7; i++) { const a = rnd() * 6.28, r = rnd() * 0.6, h = rr(3.5, 5.2), lean = rr(-0.12, 0.12);
    B.add('plain', new THREE.CylinderGeometry(0.05, 0.065, h, 5), M(t + Math.cos(a) * r, h / 2, -s + Math.sin(a) * r, 0, lean, lean), i % 2 ? '#6d9a4a' : '#5a8a3d');
    B.add('leaf', new THREE.IcosahedronGeometry(rr(0.45, 0.7), 1), M(t + Math.cos(a) * r, h - 0.2, -s + Math.sin(a) * r, 0, 0, 0, 1, 1.4, 1), leafCol(['#8cc063', '#7bb257', '#9bcb6c'])); }
  addColl(t - 0.8, t + 0.8, s - 0.8, s + 0.8);
}
// 黄葛树：树冠单独一个网格，人走到树下时变淡
function heroTree(B, Bc, t, s) {
  const x = t, z = -s;
  B.add('bark', new THREE.CylinderGeometry(0.72, 1.2, 5.2, 9), M(x, 2.6, z));
  for (let k = 0; k < 6; k++) { const a = k * 1.05 + 0.3; B.add('bark', new THREE.CylinderGeometry(0.1, 0.5, 2.0, 5), M(x + Math.cos(a) * 1.05, 0.65, z + Math.sin(a) * 1.05, -a, 0, -0.75)); }
  for (let k = 0; k < 6; k++) { const a = k * 1.05 + 0.8, tilt = rr(0.85, 1.1), L = rr(3.6, 4.6), dx = Math.sin(tilt) * Math.cos(a), dy = Math.cos(tilt), dz = Math.sin(tilt) * Math.sin(a);
    B.add('bark', new THREE.CylinderGeometry(0.16, 0.36, L, 6), M(x + dx * L / 2, 4.4 + dy * L / 2, z + dz * L / 2, -a, 0, -tilt)); }
  for (let k = 0; k < 14; k++) { const a = rnd() * 6.28, r = rr(1.8, 4.8), L = rr(2.6, 4.0); B.add('bark', new THREE.CylinderGeometry(0.035, 0.05, L, 4), M(x + Math.cos(a) * r, 6.1 - L / 2, z + Math.sin(a) * r), '#8a6a52'); }
  for (let i = 0; i < 28; i++) { const a = i * 2.39996, r = 6.3 * Math.sqrt((i + 0.5) / 28), sz = rr(1.6, 2.5);
    Bc.add('leaf', new THREE.IcosahedronGeometry(sz, 1), M(x + Math.cos(a) * r, 7.2 + (1 - r / 6.3) * 1.7 + rr(-0.4, 0.4), z + Math.sin(a) * r, rnd() * 3, 0, 0, 1, 0.78, 1), leafCol(LEAVES_HERO)); }
  for (let k = 0; k < 6; k++) { const a = k * 1.05; B.add('slab', new THREE.CylinderGeometry(0.34, 0.38, 0.42, 7), M(x + Math.cos(a) * 3.1, 0.21, z + Math.sin(a) * 3.1), '#b9b2b8'); }
  addColl(t - 1.4, t + 1.4, s - 1.4, s + 1.4);
}
function stall(B, Bo, Bc, t, s, awn, seed) {
  const x = t, z = -s;
  B.add('wood', boxG(2.4, 0.12, 1.1, 1.2), M(x, 0.8, z));
  for (const [dx, dz] of [[-1.1, -0.45], [1.1, -0.45], [-1.1, 0.45], [1.1, 0.45]]) B.add('wood', boxG(0.1, 0.8, 0.1, 1), M(x + dx, 0.4, z + dz));
  if (Bo) {
    for (const [dx, dz] of [[-1.25, -0.7], [1.25, -0.7], [-1.25, 0.75], [1.25, 0.75]]) Bo.add('wood', boxG(0.08, dz < 0 ? 2.45 : 2.15, 0.08, 1), M(x + dx, dz < 0 ? 1.22 : 1.07, z + dz));
    Bo.add(`awning:${awn[0]}|${awn[1]}`, boxG(2.9, 0.06, 1.8, 1.45), M(x, 2.3, z + 0.05, 0, 0.18));
    const R = mulberry32(seed);
    for (let k = 0; k < 6; k++) { const bx = x - 0.95 + (k % 3) * 0.95, bz = z - 0.25 + Math.floor(k / 3) * 0.5;
      Bo.add('wood', new THREE.CylinderGeometry(0.26, 0.2, 0.16, 8), M(bx, 0.94, bz));
      const col = GOODS[Math.floor(R() * GOODS.length)];
      for (let j = 0; j < 4; j++) Bo.add('plain', new THREE.IcosahedronGeometry(0.1, 0), M(bx + (R() - 0.5) * 0.25, 1.06 + R() * 0.06, bz + (R() - 0.5) * 0.25), col); }
  }
  if (Bc) Bc.add('plain', boxG(2.55, 0.28, 1.25, 1), M(x, 0.98, z), '#6f685e');
  addColl(t - 1.35, t + 1.35, s - 0.8, s + 0.8);
}
function lampPost(B, t, s) {
  B.add('wood', boxG(0.14, 2.3, 0.14, 1), M(t, 1.15, -s)); B.add('wood', boxG(0.6, 0.08, 0.08, 1), M(t + 0.25, 2.28, -s));
  lantern(B, t + 0.5, 1.95, -s); addColl(t - 0.25, t + 0.25, s - 0.25, s + 0.25);
}
function wallRun(B, t0, s0, t1, s1, h = 1.6, key = 'white', cap = P.tile) { // 院墙，沿 t 或 s
  const len = Math.hypot(t1 - t0, s1 - s0), alongT = Math.abs(t1 - t0) > Math.abs(s1 - s0), cx = (t0 + t1) / 2, cs = (s0 + s1) / 2;
  const g = alongT ? boxG(len, h, 0.3, 2) : boxG(0.3, h, len, 2);
  B.add(key, g, M(cx, h / 2, -cs)); B.add('tile', alongT ? boxG(len + 0.2, 0.14, 0.55, 1.2) : boxG(0.55, 0.14, len + 0.2, 1.2), M(cx, h + 0.07, -cs), cap);
  if (alongT) addColl(t0, t1, cs - 0.3, cs + 0.3); else addColl(cx - 0.3, cx + 0.3, s0, s1);
}
function gate(B, parent, t, s, width, text, opts = {}) { // 两根柱子加一道横梁挂匾
  const h = opts.h || 3.4;
  for (const sg of [-1, 1]) { B.add(opts.post || 'wood', boxG(0.34, h, 0.34, 1), M(t + sg * width / 2, h / 2, -s), opts.postCol); B.add('slab', boxG(0.55, 0.3, 0.55, 1), M(t + sg * width / 2, 0.15, -s)); addColl(t + sg * width / 2 - 0.3, t + sg * width / 2 + 0.3, s - 0.3, s + 0.3); }
  B.add('wood', boxG(width + 0.8, 0.28, 0.36, 1), M(t, h - 0.1, -s), opts.beamCol);
  roof(B, t, -s, width + 0.2, 1.0, h + 0.05, 'tile', 0.42, 0.32);
  if (text) addSign(parent, text, t, h - 0.72, s - 0.34, 0.62, opts.sign || {});
}
