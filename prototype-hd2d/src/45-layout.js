// =====================================================================
// 苏七镇布局：按阿鱼标注的实地地图，由北向南
// 罗曼山庄 → 牌坊 → 本地人集市 → 镇政府／苏七小学（门口黄葛树）→ 老街 → 石板桥 → 河南岸住宅区、游客集市；月老庙在河对岸西边
// 桥是老街到住宅区唯一的路
// =====================================================================
const REFS = { lamps: [], boats: [], npcs: [], crops: [] };
const AREAS = [
  { t0: T0, t1: T1, s0: 15, s1: 17.2, k: 'stone' }, { t0: -45, t1: 34, s0: 17.2, s1: 22.6, k: 'stone' },
  { t0: 33, t1: 45.5, s0: 15, s1: 19.4, k: 'stone' }, { t0: -3.2, t1: 3.2, s0: 22, s1: 46, k: 'stone' },
  { t0: -31, t1: -3, s0: 30.2, s1: 46.6, k: 'stone' }, { t0: -3.2, t1: 3.2, s0: 46, s1: 101, k: 'dirt' },
  { t0: -20, t1: 20, s0: 69, s1: 91, k: 'dirt' }, { t0: -28, t1: 28, s0: 77.5, s1: 82.5, k: 'dirt' },
  { t0: -31.6, t1: -6.4, s0: 47.4, s1: 55.5, k: 'dirt' }, { t0: 5, t1: 25, s0: 51, s1: 58, k: 'stone' },
  { t0: -14, t1: 14, s0: 96.5, s1: 110.5, k: 'stone' },
  { t0: T0, t1: T1, s0: -17.2, s1: -15, k: 'stone' }, { t0: -72, t1: 50, s0: -21, s1: -17.2, k: 'dirt' },
  { t0: -2.6, t1: 2.6, s0: -61, s1: -17, k: 'dirt' }, { t0: -44, t1: 30, s0: -40.5, s1: -35.4, k: 'dirt' },
  { t0: -44, t1: 30, s0: -57.5, s1: -54.4, k: 'dirt' }, { t0: 28, t1: 50, s0: -46, s1: -21, k: 'dirt' },
  { t0: -52, t1: -48, s0: -47, s1: -21, k: 'dirt' }, { t0: -72, t1: -48, s0: -47.5, s1: -41.4, k: 'dirt' },
  { t0: -69.6, t1: -50.4, s0: -40.6, s1: -25.4, k: 'court' },
];
const HOUSE_T = [-33, -23, -13, 9, 19], ROWS = [-30, -48.5];
for (const f of ROWS) for (const t of HOUSE_T) AREAS.push({ t0: t - 3.4, t1: t + 3.4, s0: f - 5.6, s1: f, k: 'yard' });

const PLACES = {
  roman: { t: 0, s: 101.6 }, market: { t: 0, s: 79 }, tree: { t: -11, s: 33.2 }, street: { t: -20, s: 19.6 },
  bridge: { t: 0, s: 14 }, home: { t: 9, s: -36.9 }, tourist: { t: 39, s: -33 }, temple: { t: -60, s: -44 }, couple: { t: 39, s: 17 },
};
const REGIONS = [
  ['罗曼山庄', -15, 15, 96.5, 124], ['牌坊', -8, 8, 90, 96.5], ['本地人集市', -28, 28, 66, 90], ['苏七小学', -33, -5, 46.6, 66],
  ['镇政府', 3, 26, 50, 70], ['黄葛树', -31, -3, 29, 46.6], ['新人家', 33, 46, 14, 27], ['老街', -46, 33, 14.5, 30],
  ['石板桥', -2, 2, -15.5, 15.5], ['月老庙', -72, -48, -48, -24], ['游客集市', 27, 50, -47, -21], ['你家', 5, 13, -40.5, -24.5],
  ['居民住宅区', -46, 26, -60, -21], ['峨眉河边', T0, T1, -22, 22],
];
const TRIG = [
  { t: 0, s: 79, r: 9, say: () => S.market ? LINES.marketOn : LINES.marketOff },
  { t: 4.5, s: 56, r: 5.5, say: () => LINES.gov }, { t: -16, s: 44.6, r: 4.2, say: () => LINES.school },
  { t: -11.5, s: 36.4, r: 2.8, say: () => LINES.leaf }, { t: -7.8, s: 34.4, r: 2, say: () => LINES.box },
  { t: 0, s: 16.2, r: 2.2, say: () => S.flood ? LINES.bridgeFlood : LINES.bridge }, { t: 0, s: -18.6, r: 2.8, say: () => LINES.southBank },
  { t: 9, s: -35.8, r: 3.2, say: () => [LINES.home, LINES.luoluoDoor] }, { t: 39, s: -24.5, r: 5, say: () => LINES.tourist },
  { t: -60, s: -43, r: 4.2, say: () => LINES.temple }, { t: -29.4, s: 29.5, r: 2.4, say: () => LINES.qiuqiuFound, who: '' },
];

function planeG(w, h, unit = 0) {
  const g = new THREE.PlaneGeometry(w, h); g.rotateX(-Math.PI / 2);
  if (unit) { const uv = g.attributes.uv; for (let i = 0; i < uv.count; i++) uv.setXY(i, uv.getX(i) * w / unit, uv.getY(i) * h / unit); }
  return g;
}

function buildRiver(town, B) {
  const L = T1 - T0, tc = (T0 + T1) / 2;
  B.add('bed', planeG(L, RIVER * 2, 4), M(tc, BED_Y, 0));
  for (const sg of [1, -1]) B.add('wall', boxG(L, -BED_Y - 0.01, 0.3, 2), M(tc, (BED_Y - 0.01) / 2, -sg * RIVER));
  for (let k = 1; k < SPANS; k++) {
    const s = -RIVER + k * SPAN_L, h = (DECK_TOP - 0.3) - BED_Y, y = BED_Y + h / 2;
    B.add('wall', boxG(2.3, h, 0.55, 1.4), M(0, y, -s));
    for (const sg of [-1, 1]) B.add('wall', boxG(0.4, h, 0.4, 1.4), M(sg * 1.15, y, -s, Math.PI / 4));
  }
  const tints = ['#ffffff', '#ebe6e8', '#dcd7db', '#f3eff1'];
  for (let k = 0; k < SPANS; k++) { const c = -RIVER + (k + 0.5) * SPAN_L; B.add('slab', boxG(DECK * 2, 0.3, SPAN_L - 0.05, 1.6), M(0, DECK_TOP - 0.15, -c), tints[k % 4]); }
  for (const sg of [-1, 1]) B.add('slab', boxG(DECK * 2, 0.3, 0.95, 1.6), M(0, DECK_TOP - 0.15, -sg * (RIVER + 0.47)), '#e4dfe2');
  const on = new THREE.MeshStandardMaterial({ color: '#f6dc8a', emissive: '#ffc45a', emissiveIntensity: 1.2, roughness: 0.5 });
  const off = new THREE.MeshStandardMaterial({ color: '#5d4f45', roughness: 0.9 });
  REFS.lampMat = { on, off };
  for (let k = SPANS - 1; k >= 0; k--) { // 从北岸（老街）往南点
    const s = -RIVER + (k + 0.5) * SPAN_L;
    B.add('slab', boxG(0.16, 0.52, 0.16, 1), M(1.0, DECK_TOP + 0.26, -s), '#cfc8cc');
    B.add('tile', boxG(0.36, 0.07, 0.36, 1.2), M(1.0, DECK_TOP + 0.93, -s));
    const head = new THREE.Mesh(boxG(0.25, 0.3, 0.25, 1), off); head.position.set(1.0, DECK_TOP + 0.72, -s); head.castShadow = true;
    town.add(head); REFS.lamps.push(head);
  }
  const wt = TEX.water; wt.repeat.set(L / 6, 30 / 6);
  REFS.water = new THREE.Mesh(planeG(L, RIVER * 2), new THREE.MeshStandardMaterial({ map: wt, transparent: true, opacity: 0.84, roughness: 0.2, metalness: 0.05, emissive: '#0b1b2c', emissiveIntensity: 0.5 }));
  REFS.water.position.set(tc, WATER_Y, 0); REFS.water.receiveShadow = true; town.add(REFS.water);
  const sp = TEX.sparkle; sp.repeat.set(L / 9, 30 / 9);
  REFS.sparkle = new THREE.Mesh(planeG(L, RIVER * 2), new THREE.MeshBasicMaterial({ map: sp, transparent: true, opacity: 0.55, blending: THREE.AdditiveBlending, depthWrite: false, color: '#e6f2ff' }));
  REFS.sparkle.position.set(tc, WATER_Y + 0.012, 0); town.add(REFS.sparkle);
  // 码头（景）和两条小船
  B.add('wood', boxG(2.2, 0.12, 3.4, 1.2), M(-58, -0.46, -13.2)); for (const [dx, dz] of [[-1, -12], [1, -12], [-1, -14.5], [1, -14.5]]) B.add('wood', new THREE.CylinderGeometry(0.08, 0.08, 1.8, 5), M(-58 + dx, -1.2, dz));
  B.add('wood', boxG(2.2, 0.5, 1.3, 1.2), M(-58, -0.2, -15.5, 0, -0.26));
  for (const [t, s] of [[-61, 13], [-55, 12.4]]) { B.add('wood', boxG(2.6, 0.3, 1.0, 1.2), M(t, WATER_Y + 0.12, -s, 0.2)); B.add('wood', boxG(2.1, 0.08, 0.7, 1.2), M(t, WATER_Y + 0.3, -s, 0.2), '#8a6140'); }
}
function makeBoat(town, s, speed, t) {
  const B = new Builder(), g = new THREE.Group();
  B.add('wood', boxG(2.6, 0.38, 1.05, 1.2), M(0, 0.12, 0)); B.add('wood', boxG(2.9, 0.12, 0.8, 1.2), M(0, 0.33, 0), '#9a6a45');
  for (const [dx, dz] of [[-0.8, -0.38], [0.8, -0.38], [-0.8, 0.38], [0.8, 0.38]]) B.add('wood', boxG(0.06, 0.9, 0.06, 1), M(dx, 0.8, dz));
  B.add(`awning:${P.red}|${P.red0}`, boxG(2.0, 0.07, 1.05, 1.45), M(0, 1.28, 0)); lantern(B, -1.15, 1.1, 0, 0.8); lantern(B, 1.15, 1.1, 0, 0.8);
  B.flush(g, { cast: false }); g.position.set(t, WATER_Y, -s); town.add(g); REFS.boats.push({ g, s, speed }); g.visible = false;
}
