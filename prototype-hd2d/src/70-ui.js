// =====================================================================
// 对白、触发、输入、面板、主循环
// =====================================================================
const $ = (id) => document.getElementById(id);
const DQ = []; let dlgT = 0, cur = null;
function say(text, who = '阿鱼') {
  if (Array.isArray(text)) { text.forEach(t => say(t, who)); return; }
  if ((cur && cur.text === text) || DQ.some(q => q.text === text)) return;
  DQ.push({ text, who });
}
function updateDialog() {
  const now = performance.now();
  if (cur && now > dlgT) { cur = null; $('dialog').hidden = true; }
  if (!cur && DQ.length) { cur = DQ.shift(); $('who').textContent = cur.who; $('line').textContent = cur.text; $('dialog').hidden = false; dlgT = now + (2.2 + cur.text.length * 0.09) * 1000; }
}
function toast(text) { const el = $('toast'); el.textContent = text; el.hidden = false; clearTimeout(toast.t); toast.t = setTimeout(() => el.hidden = true, 1800); }
const armed = TRIG.map(() => true);
function updateTriggers() {
  TRIG.forEach((tr, i) => {
    const d = Math.hypot(PLAYER.t - tr.t, PLAYER.s - tr.s);
    if (d < tr.r && armed[i]) { armed[i] = false; say(tr.say(), tr.who ?? '阿鱼'); if (tr.t === -29.4) { const q = ACT.pets.find(p => p.name === '求求'); if (q) q.hop = 0.35; } }
    else if (d > tr.r + 3) armed[i] = true;
  });
}
const regionName = (t, s) => { for (const [n, t0, t1, s0, s1] of REGIONS) if (t >= t0 && t <= t1 && s >= s0 && s <= s1) return n; return '苏七镇'; };
const fmtH = (h) => `${String(Math.floor(h) % 24).padStart(2, '0')}:${String(Math.floor((h % 1) * 60)).padStart(2, '0')}`;

// ---------- 输入：点地面走、点动物和球、滚轮和双指缩放、方向键 ----------
const keys = new Set(), ray = new THREE.Raycaster(), ndc = new THREE.Vector2(), GROUND = new THREE.Plane(new THREE.Vector3(0, 1, 0), 0);
let TAP = null;
function hideHint() { $('hint').style.opacity = 0; }
function setZoom(z) { S.zoom = Math.max(20, Math.min(52, z)); $('zoom').value = Math.round(S.zoom); $('zoom-val').textContent = Math.round(S.zoom); }
function goTo(t, s, stopShort = 0) {
  const path = findPath({ t: PLAYER.t, s: PLAYER.s }, { t, s }); if (!path || !path.length) return false;
  if (stopShort) { const L = path[path.length - 1], pv = path.length > 1 ? path[path.length - 2] : PLAYER, d = Math.hypot(L.t - pv.t, L.s - pv.s); if (d > stopShort) path[path.length - 1] = { t: L.t - (L.t - pv.t) / d * stopShort, s: L.s - (L.s - pv.s) / d * stopShort }; else path.pop(); }
  PLAYER.path = path.length ? path : null; return true;
}
function interact(p) {
  const d = Math.hypot(p.ref.t - PLAYER.t, p.ref.s - PLAYER.s);
  PLAYER.pending = p;
  if (d < (p.kind === 'ball' ? 1.7 : 2.6)) { PLAYER.path = null; arrive(); }
  else if (!goTo(p.ref.t, p.ref.s, p.kind === 'ball' ? 1.0 : 1.5)) arrive();
}
function tap(e) {
  const r = renderer.domElement.getBoundingClientRect();
  ndc.set(((e.clientX - r.left) / r.width) * 2 - 1, -((e.clientY - r.top) / r.height) * 2 + 1); ray.setFromCamera(ndc, camera);
  const hits = ray.intersectObjects(ACT.pick.filter(p => p.mesh.visible).map(p => p.mesh), false);
  hideHint();
  if (hits.length) { interact(ACT.pick.find(x => x.mesh === hits[0].object)); return; }
  const pt = new THREE.Vector3(); if (!ray.ray.intersectPlane(GROUND, pt)) return;
  const f = toFrame(pt.x, pt.z); PLAYER.pending = null;
  if (goTo(f.t, f.s)) { TAP.position.set(pt.x, 0.04, pt.z); TAP.userData.life = 1; }
}
function bindInput() {
  const cv = renderer.domElement, ptrs = new Map(); let down = null, pinch0 = 0, zoom0 = 0;
  cv.addEventListener('pointerdown', e => { cv.setPointerCapture(e.pointerId); ptrs.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (ptrs.size === 2) { const [a, b] = [...ptrs.values()]; pinch0 = Math.hypot(a.x - b.x, a.y - b.y); zoom0 = S.zoom; down = null; } else down = { x: e.clientX, y: e.clientY }; });
  cv.addEventListener('pointermove', e => { if (!ptrs.has(e.pointerId)) return; ptrs.set(e.pointerId, { x: e.clientX, y: e.clientY });
    if (ptrs.size === 2) { const [a, b] = [...ptrs.values()]; setZoom(zoom0 * pinch0 / Math.max(20, Math.hypot(a.x - b.x, a.y - b.y))); } });
  cv.addEventListener('pointerup', e => { ptrs.delete(e.pointerId); if (down && Math.hypot(e.clientX - down.x, e.clientY - down.y) < 12) tap(e); down = null; });
  cv.addEventListener('pointercancel', e => { ptrs.delete(e.pointerId); down = null; });
  cv.addEventListener('wheel', e => { e.preventDefault(); setZoom(S.zoom * (1 + Math.sign(e.deltaY) * 0.08)); }, { passive: false });
  const K = ['ArrowUp', 'ArrowDown', 'ArrowLeft', 'ArrowRight', 'w', 'a', 's', 'd'];
  addEventListener('keydown', e => { if (e.target.tagName === 'INPUT' || e.target.tagName === 'BUTTON') return; const k = e.key.length === 1 ? e.key.toLowerCase() : e.key; if (K.includes(k)) { keys.add(k); hideHint(); e.preventDefault(); } });
  addEventListener('keyup', e => keys.delete(e.key.length === 1 ? e.key.toLowerCase() : e.key));
  addEventListener('blur', () => keys.clear());
  addEventListener('resize', resize);
}

// ---------- 面板 ----------
function applyMarket() { REFS.marketOpen.visible = S.market; REFS.marketClosed.visible = !S.market; REFS.npcs.forEach(n => { n.m.visible = n.b.visible = (n.key === 'tourist' || S.market); }); }
function applyLamps(prev) {
  REFS.lamps.forEach((m, i) => m.material = i < S.lamps ? REFS.lampMat.on : REFS.lampMat.off);
  $('lamps-val').textContent = `${S.lamps}／17`;
  if (prev !== undefined) { if (S.lamps === 17 && prev < 17) toast(LINES.lampAll); else if (S.lamps > prev) toast(LINES.lampOne); }
}
function syncHour() { $('hour').value = S.hour; $('hour-val').textContent = fmtH(S.hour); }
function setHour(h, manual = true) { S.hour = h; if (manual) { S.follow = false; $('follow').checked = false; } applyTime(h); syncHour(); }
function bindPanel() {
  $('follow').addEventListener('change', e => { S.follow = e.target.checked; if (S.follow) setHour(bj().h, false); });
  $('hour').addEventListener('input', e => setHour(+e.target.value));
  $('presets').addEventListener('click', e => { const h = e.target.dataset.h; if (h) setHour(+h); });
  $('market').checked = S.market; $('market').addEventListener('change', e => { S.market = e.target.checked; applyMarket(); });
  $('flood').checked = S.flood; $('flood').addEventListener('change', e => { S.flood = e.target.checked; });
  $('lamps').addEventListener('input', e => { const prev = S.lamps; S.lamps = +e.target.value; applyLamps(prev); });
  const qb = [...document.querySelectorAll('#quality button')], mark = () => qb.forEach(b => b.setAttribute('aria-pressed', String(b.dataset.q === S.quality)));
  qb.forEach(b => b.addEventListener('click', () => { S.quality = b.dataset.q; mark(); applyQuality(); })); mark();
  $('zoom').addEventListener('input', e => setZoom(+e.target.value));
  $('jumps').addEventListener('click', e => { const k = e.target.dataset.go; if (!k) return; const p = PLACES[k]; Object.assign(PLAYER, { t: p.t, s: p.s, path: null, pending: null }); const w = toWorld(p.t, p.s); camTarget.set(w.x, 0.9, w.z); closePanel(); });
  const tg = $('panel-toggle'), pn = $('panel');
  function closePanel() { pn.classList.remove('open'); tg.setAttribute('aria-expanded', 'false'); }
  tg.addEventListener('click', () => { const o = pn.classList.toggle('open'); tg.setAttribute('aria-expanded', String(o)); });
}

// ---------- 主循环 ----------
let last = performance.now(), time = 0, clockT = 20, labelT = 0, fpsT = 0, fpsN = 0;
function loop(now) {
  const dt = Math.min(0.05, (now - last) / 1000); last = now; time += dt;
  if (S.follow) { clockT -= dt; if (clockT <= 0) { clockT = 20; setHour(bj().h, false); } }
  updatePlayer(dt, keys); updateWorldActors(dt, time); updateTriggers(); updateDialog(); updateLights(dt); updateCamera(dt);
  const wy = S.flood ? FLOOD_Y : WATER_Y; REFS.water.position.y += (wy - REFS.water.position.y) * Math.min(1, dt * 1.5); REFS.sparkle.position.y = REFS.water.position.y + 0.012;
  const flow = S.flood ? 0.09 : 0.045; TEX.water.offset.x -= dt * flow; TEX.sparkle.offset.x -= dt * flow * 2.2;
  for (const b of REFS.boats) { b.g.position.x += b.speed * dt; if (b.g.position.x > T1 - 4) b.g.position.x = T0 + 4; if (b.g.position.x < T0 + 4) b.g.position.x = T1 - 4; b.g.position.y = REFS.water.position.y + Math.sin(time * 1.5 + b.s) * 0.04; }
  REFS.motes.position.set(camTarget.x, 0, camTarget.z); REFS.motes.material.uniforms.uTime.value = time;
  const cm = REFS.canopy.material, under = Math.hypot(PLAYER.t + 13, PLAYER.s - 39.5) < 7; cm.opacity += ((under ? 0.32 : 1) - cm.opacity) * Math.min(1, dt * 4); cm.depthWrite = cm.opacity > 0.97;
  const kf = Math.min(1, dt * 5);
  for (const g of REFS.fadeGroups) { const tgtO = g.test(PLAYER.t, PLAYER.s) ? 0.2 : 1;
    for (const mt of g.mats) { mt.opacity += (tgtO - mt.opacity) * kf; const tr = mt.opacity < 0.99;
      if (mt.transparent !== tr) { mt.transparent = tr; mt.needsUpdate = true; } mt.depthWrite = !tr; } }
  if (TAP.userData.life > 0) { TAP.userData.life -= dt * 1.6; TAP.scale.setScalar(1 + (1 - TAP.userData.life) * 1.2); TAP.material.opacity = Math.max(0, TAP.userData.life); }
  labelT -= dt; if (labelT <= 0) { labelT = 0.25; $('place-name').textContent = regionName(PLAYER.t, PLAYER.s); $('clock-tag').textContent = (S.market ? '赶场日' : '双日') + (isNightTour(S.hour) ? ' · 夜游' : '') + (S.flood ? ' · 涨水' : ''); $('clock-time').textContent = fmtH(S.hour); }
  renderFrame();
  fpsN++; fpsT += dt; if (fpsT >= 0.5) { $('fps').textContent = `${Math.round(fpsN / fpsT)} / ${renderer.info.render.calls}`; fpsN = 0; fpsT = 0; }
  requestAnimationFrame(loop);
}

async function init() {
  try { await Promise.race([document.fonts.load('22px "ZCOOL XiaoWei"', '苏七镇小学种子铺木匠茶翘儿罗曼山庄月老庙周报'), new Promise(r => setTimeout(r, 2500))]); } catch (e) { /* 字体没到就用系统宋体 */ }
  TEX = makeTextures(); ATLAS = buildAtlas();
  setupRender($('c')); buildTown(scene); buildGrid(); buildActors(scene);
  TAP = new THREE.Mesh(new THREE.RingGeometry(0.28, 0.38, 24).rotateX(-Math.PI / 2), new THREE.MeshBasicMaterial({ color: P.gold1, transparent: true, opacity: 0, depthWrite: false })); TAP.userData.life = 0; scene.add(TAP);
  bindInput(); bindPanel(); applyQuality(); applyTime(S.hour); syncHour(); applyMarket(); applyLamps(); setZoom(S.zoom);
  const w = toWorld(PLAYER.t, PLAYER.s); camTarget.set(w.x, 0.9, w.z);
  $('loading').hidden = true; setTimeout(hideHint, 9000);
  say([LINES.arrive, LINES.leave]);
  requestAnimationFrame(loop);
}
init().catch(err => { $('loading').textContent = '没搭起来：' + err.message; console.error(err); });
