// =====================================================================
// 会动的东西：宾客（玩家）、四只动物、镇上的人、四个球、作物、飞虫
// 精灵在世界坐标里，永远朝 +z（相机只朝北看，不转）
// =====================================================================
let SPRITE_MAT, SPRITE_DEPTH;
const SPPU = 18;                      // 精灵每单位像素
const ACT = { pets: [], balls: [], pick: [] };
function setUV(geo, name, flip) {
  const f = ATLAS.FR[name], u0 = f.x / ATLAS.AW, u1 = (f.x + f.w) / ATLAS.AW, v1 = 1 - f.y / ATLAS.AH, v0 = 1 - (f.y + f.h) / ATLAS.AH;
  const a = flip ? u1 : u0, b = flip ? u0 : u1, uv = geo.attributes.uv;
  uv.setXY(0, a, v1); uv.setXY(1, b, v1); uv.setXY(2, a, v0); uv.setXY(3, b, v0); uv.needsUpdate = true;
}
function sprite(name, ppu = SPPU) {
  const f = ATLAS.FR[name], w = f.w / ppu, h = f.h / ppu, geo = new THREE.PlaneGeometry(w, h); geo.translate(0, h / 2, 0); setUV(geo, name, false);
  const m = new THREE.Mesh(geo, SPRITE_MAT); m.castShadow = true; m.customDepthMaterial = SPRITE_DEPTH; return m;
}
function blob(scene, size) { const m = new THREE.Mesh(new THREE.PlaneGeometry(size, size * 0.55).rotateX(-Math.PI / 2), BLOB_MAT); m.renderOrder = 1; scene.add(m); return m; }
let BLOB_MAT;
function placeW(obj, t, s, y = 0) { const w = toWorld(t, s); obj.position.set(w.x, y, w.z); }

function buildActors(scene) {
  SPRITE_MAT = new THREE.MeshStandardMaterial({ map: ATLAS.tex, alphaTest: 0.5, side: THREE.DoubleSide, roughness: 1, emissive: '#ffffff', emissiveMap: ATLAS.tex, emissiveIntensity: 0.06 });
  SPRITE_DEPTH = new THREE.MeshDepthMaterial({ depthPacking: THREE.RGBADepthPacking, map: ATLAS.tex, alphaTest: 0.5 });
  BLOB_MAT = new THREE.MeshBasicMaterial({ map: TEX.blob, transparent: true, depthWrite: false });

  // 作物：静止的一片，合成一个网格
  const geos = REFS.crops.map(c => { const n = c.kind + c.st, f = ATLAS.FR[n], w = f.w / 12, h = f.h / 12, g = new THREE.PlaneGeometry(w, h); setUV(g, n, hash2(c.t * 10, c.s) > 0.5); const p = toWorld(c.t, c.s); g.translate(p.x, h / 2 + 0.14, p.z); return g; });
  if (geos.length) { const cm = new THREE.Mesh(mergeGeometries(geos), SPRITE_MAT); cm.castShadow = true; cm.customDepthMaterial = SPRITE_DEPTH; scene.add(cm); }

  // 宾客
  const pm = sprite('guest_down0'); scene.add(pm);
  PLAYER.mesh = pm; PLAYER.blob = blob(scene, 0.95);
  Object.assign(PLAYER, { t: PLACES.roman.t, s: PLACES.roman.s });

  // 动物
  const pet = (name, frames, t, s, area, speed, line, ppu = SPPU) => { const m = sprite(frames[0], ppu); scene.add(m); const p = { name, frames, t, s, area, speed, line, mesh: m, blob: blob(scene, 0.7), tgt: null, wait: rr(0.5, 2), flip: false, anim: 0, hop: 0 }; ACT.pets.push(p); ACT.pick.push({ mesh: m, kind: 'pet', ref: p }); return p; };
  pet('喜多', ['corgi0', 'corgi1', 'corgi0'], 38, 17.2, [34, 44, 15.6, 18.8], 1.5, LINES.xiduo, 20);
  pet('天天', ['tiantian0', 'tiantian1', 'tiantian_sit'], -18, 19.5, [-36, 30, 17.6, 21.8], 1.1, LINES.tiantian, 20);
  pet('落落', ['luoluo_sleep'], 9.6, -30.55, null, 0, LINES.luoluo, 20);
  const qq = pet('求求', ['qiuqiu_sit'], -29.4, 29.35, null, 0, LINES.qiuqiu, 20); qq.hide = true;

  // 镇上的人（系统 NPC）：赶场日本地人集市多几个，游客集市一直有
  for (const [key, list] of Object.entries(REFS.npcSpots)) for (const [t, s, v] of list) {
    const m = sprite(`npc${v}_down0`); placeW(m, t, s, 0); scene.add(m); const b = blob(scene, 0.9); placeW(b, t, s, 0.02);
    REFS.npcs.push({ key, m, b, v, flip: false, next: rr(1, 4) });
  }

  // 四个球：红、黄、蓝、一个破的旧球。每天换位置，同一天所有人看到的一样
  const dayKey = (() => { const d = bj(); return d.mo * 100 + d.day; })();
  const spots = [['red', -19, 51], ['yellow', -17.5, 35.3], ['blue', -23, 19.6], ['old', 3.6, 18.4]];
  const cols = { red: [P.red, P.paper1], yellow: [P.gold, P.red], blue: [P.blu, P.paper1], old: ['#9c8b72', '#6d6048'] };
  spots.forEach(([c, t, s], i) => {
    const p = new Pix(16, 8); p.rect(0, 0, 16, 8, cols[c][0]); p.rect(0, 3, 16, 2, cols[c][1]); if (c === 'old') p.specks(0, 0, 16, 8, '#5a4e3c', 0.2);
    const m = new THREE.Mesh(new THREE.SphereGeometry(0.21, 12, 8), new THREE.MeshStandardMaterial({ map: texFrom(p.done(), { repeat: false }), roughness: 0.7 }));
    m.castShadow = true; scene.add(m);
    const b = { c, t: t + (hash2(dayKey, i) - 0.5) * 3, s: s + (hash2(i, dayKey) - 0.5) * 1.2, vt: 0, vs: 0, mesh: m, kicks: 0, kickedByMe: false };
    if (!walkable(b.t, b.s, 0.25)) { b.t = t; b.s = s; }
    ACT.balls.push(b); ACT.pick.push({ mesh: m, kind: 'ball', ref: b });
  });

  // 树上属于你的那片叶子
  REFS.leaf = sprite('leaf', 14); REFS.leaf.castShadow = false; placeW(REFS.leaf, -11.4, 34.6, 5.2); scene.add(REFS.leaf);

  // 飞虫：白天是浮尘，天黑是萤火
  const N = 150, pos = new Float32Array(N * 3), ph = new Float32Array(N);
  for (let i = 0; i < N; i++) { pos[i * 3] = rr(-16, 16); pos[i * 3 + 1] = rr(0.3, 4.5); pos[i * 3 + 2] = rr(-18, 12); ph[i] = rnd() * 6.28; }
  const pg = new THREE.BufferGeometry(); pg.setAttribute('position', new THREE.BufferAttribute(pos, 3)); pg.setAttribute('phase', new THREE.BufferAttribute(ph, 1));
  REFS.motes = new THREE.Points(pg, new THREE.ShaderMaterial({
    uniforms: { uTime: { value: 0 }, uColor: { value: new THREE.Color('#fff2c8') }, uAlpha: { value: 0.35 }, uSize: { value: 26 } },
    vertexShader: 'attribute float phase; uniform float uTime; uniform float uSize; varying float vA; void main(){ vec3 p = position; p.y += sin(uTime*0.6+phase)*0.25; p.x += sin(uTime*0.35+phase*2.0)*0.4; vec4 mv = modelViewMatrix*vec4(p,1.0); gl_Position = projectionMatrix*mv; gl_PointSize = uSize/ -mv.z; vA = 0.5+0.5*sin(uTime*1.7+phase*3.0); }',
    fragmentShader: 'uniform vec3 uColor; uniform float uAlpha; varying float vA; void main(){ vec2 d = gl_PointCoord-0.5; float a = smoothstep(0.5,0.0,length(d)); gl_FragColor = vec4(uColor, a*uAlpha*vA); }',
    transparent: true, depthWrite: false, blending: THREE.AdditiveBlending,
  }));
  REFS.motes.frustumCulled = false; scene.add(REFS.motes);

  // 涨水时踩出的水圈
  REFS.rings = []; for (let i = 0; i < 8; i++) { const r = new THREE.Mesh(new THREE.RingGeometry(0.18, 0.24, 20).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: '#e6f4ff', transparent: true, opacity: 0, depthWrite: false })); scene.add(r); REFS.rings.push({ m: r, life: 0 }); }
}

const PLAYER = { t: 0, s: 0, dir: 'down', flip: false, anim: 0, path: null, speed: 4.6, pending: null, moving: false, ring: 0 };
function frameFor(prefix, dir, k) { return `${prefix}_${dir}${k}`; }
function updatePlayer(dt, keys) {
  const p = PLAYER; let vt = 0, vs = 0;
  let kx = (keys.has('ArrowRight') || keys.has('d') ? 1 : 0) - (keys.has('ArrowLeft') || keys.has('a') ? 1 : 0);
  let kz = (keys.has('ArrowDown') || keys.has('s') ? 1 : 0) - (keys.has('ArrowUp') || keys.has('w') ? 1 : 0);
  let wx = 0, wz = 0;
  if (kx || kz) { p.path = null; p.pending = null; const l = Math.hypot(kx, kz); wx = kx / l; wz = kz / l; }
  else if (p.path && p.path.length) {
    const tg = p.path[0], dt_ = tg.t - p.t, ds = tg.s - p.s, d = Math.hypot(dt_, ds);
    if (d < 0.12) { p.path.shift(); if (!p.path.length) { p.path = null; arrive(); } }
    else { const wv = toWorld(dt_ / d, ds / d); wx = wv.x; wz = wv.z; }
  }
  p.moving = !!(wx || wz);
  if (p.moving) {
    const step = p.speed * dt, f = toFrame(wx * step, wz * step);
    if (walkable(p.t + f.t, p.s + f.s)) { p.t += f.t; p.s += f.s; }
    else if (walkable(p.t + f.t, p.s)) p.t += f.t;
    else if (walkable(p.t, p.s + f.s)) p.s += f.s;
    else if (p.path) { p.stuck = (p.stuck || 0) + dt; if (p.stuck > 0.35) { p.path.shift(); p.stuck = 0; if (!p.path.length) p.path = null; } }
    if (Math.abs(wx) > Math.abs(wz) * 1.2) { p.dir = 'side'; p.flip = wx < 0; } else p.dir = wz < 0 ? 'up' : 'down';
    p.anim += dt;
  } else p.anim = 0;
  const seq = [1, 0, 2, 0], k = p.moving ? seq[Math.floor(p.anim / 0.13) % 4] : 0;
  setUV(p.mesh.geometry, frameFor('guest', p.dir, k), p.flip);
  const y = groundY(p.t, p.s); placeW(p.mesh, p.t, p.s, y); placeW(p.blob, p.t, p.s, y + 0.02);
  if (S.flood && p.moving && Math.abs(p.s) < RIVER + 0.9) { p.ring -= dt; if (p.ring <= 0) { p.ring = 0.22; const r = REFS.rings.find(x => x.life <= 0); if (r) { r.life = 1; placeW(r.m, p.t, p.s, FLOOD_Y + 0.01); } } }
}
function arrive() {
  const a = PLAYER.pending; PLAYER.pending = null; if (!a) return;
  if (a.kind === 'pet') sayPet(a.ref); else if (a.kind === 'ball') kickBall(a.ref);
}
function sayPet(p) { p.hop = 0.35; say(p.line); if (p.hide && !p.found) { p.found = true; } }
function kickBall(b) {
  if (b.kickedByMe) { say(LINES.kicked, ''); return; }
  const dt_ = b.t - PLAYER.t, ds = b.s - PLAYER.s, d = Math.hypot(dt_, ds) || 1;
  b.vt = dt_ / d * 4.2; b.vs = ds / d * 4.2; b.kickedByMe = true; b.kicks++;
  say(`今天被踢了 ${b.kicks} 脚`, '');
}
function updateWorldActors(dt, time) {
  for (const p of ACT.pets) {
    if (p.area) {
      if (!p.tgt) { p.wait -= dt; if (p.wait <= 0) { for (let k = 0; k < 8; k++) { const t = rr(p.area[0], p.area[1]), s = rr(p.area[2], p.area[3]); if (walkable(t, s, 0.25)) { p.tgt = { t, s }; break; } } p.wait = rr(1.5, 4); } }
      else { const dt_ = p.tgt.t - p.t, ds = p.tgt.s - p.s, d = Math.hypot(dt_, ds);
        if (d < 0.1) p.tgt = null;
        else { const nt = p.t + dt_ / d * p.speed * dt, ns = p.s + ds / d * p.speed * dt; if (walkable(nt, ns, 0.2)) { p.t = nt; p.s = ns; } else p.tgt = null; p.flip = toWorld(dt_, ds).x < 0; p.anim += dt; } }
      const fr = p.tgt ? p.frames[Math.floor(p.anim / 0.18) % 2] : p.frames[2];
      setUV(p.mesh.geometry, fr, p.flip);
    }
    p.hop = Math.max(0, p.hop - dt);
    const y = groundY(p.t, p.s) + Math.sin(p.hop / 0.35 * Math.PI) * 0.25 * (p.hop > 0 ? 1 : 0);
    placeW(p.mesh, p.t, p.s, y); placeW(p.blob, p.t, p.s, groundY(p.t, p.s) + 0.02);
  }
  for (const n of REFS.npcs) { n.next -= dt; if (n.next <= 0) { n.next = rr(2, 5); const side = rnd() > 0.5; setUV(n.m.geometry, `npc${n.v}_${side ? 'side0' : 'down0'}`, side && rnd() > 0.5); } n.m.position.y = Math.abs(Math.sin(time * 1.3 + n.v)) * 0.02; }
  for (const b of ACT.balls) {
    const sp = Math.hypot(b.vt, b.vs);
    if (sp > 0.01) { const nt = b.t + b.vt * dt, ns = b.s + b.vs * dt; if (walkable(nt, ns, 0.22)) { b.t = nt; b.s = ns; } else { b.vt *= -0.4; b.vs *= -0.4; }
      const k = Math.max(0, sp - 3.2 * dt) / sp; b.vt *= k; b.vs *= k; const w = toWorld(b.vt, b.vs); b.mesh.rotation.z -= w.x * dt / 0.21; b.mesh.rotation.x += w.z * dt / 0.21; }
    placeW(b.mesh, b.t, b.s, groundY(b.t, b.s) + 0.21);
  }
  REFS.leaf.position.y = 5.2 + Math.sin(time * 1.4) * 0.12;
  for (const r of REFS.rings) if (r.life > 0) { r.life -= dt * 1.4; const k = 1 - r.life; r.m.scale.setScalar(1 + k * 3); r.m.material.opacity = Math.max(0, r.life) * 0.7; }
}
