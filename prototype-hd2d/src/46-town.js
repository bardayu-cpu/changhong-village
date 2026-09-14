function buildTown(scene) {
  const town = new THREE.Group(); town.rotation.y = -TH; scene.add(town);
  const B = new Builder(), BMo = new Builder(), BMc = new Builder(), BC = new Builder(), BR = new Builder(), BS = [new Builder(), new Builder()];
  REFS.rowSigns = [];

  // 地面：北岸、南岸各一张
  for (const [s0, s1] of [[RIVER, S1], [S0, -RIVER]]) {
    const g = new THREE.Mesh(planeG(T1 - T0, s1 - s0), new THREE.MeshStandardMaterial({ map: paintGround(AREAS, s0, s1), roughness: 1 }));
    g.position.set((T0 + T1) / 2, 0, -(s0 + s1) / 2); g.receiveShadow = true; town.add(g);
  }
  buildRiver(town, B);
  [[-6, 1.3, -40], [2.5, -1.1, 0], [8.5, 1.5, 30]].forEach(([s, v, t]) => makeBoat(town, s, v, t));

  // ---- 老街：铺子朝河，桥头留出主街 ----
  const SHOPS = [[-40, 'closed'], [-33.5, 'seed', '种子铺'], [-27, 'tea', '茶铺子'], [-20.5, 'closed'], [-14, 'house2'], [-7.5, 'carp', '木匠铺'],
    [7, 'beef', '翘 jio 儿'], [13.5, 'closed'], [20, 'house2'], [26.5, 'closed']];
  for (const [t, kind, name] of SHOPS) {
    const shop = kind !== 'house2';
    const r = house(BR, { t, s: 22.6, w: 6, d: 6.2, h: 4.6, facade: kind, eave: shop, lanterns: shop ? 2 : 0 });
    if (name) { const sg = addSign(town, name, t, r.signY, r.signZ, 0.6); sg.material = sg.material.clone(); SIGN_MATS.push(sg.material); REFS.rowSigns.push(sg); }
  }
  house(B, { t: 39, s: 19.4, w: 7, d: 6.5, h: 4.8, facade: 'couple', lanterns: 4 });            // 新人家：老街尽头临河
  for (const t of [-38, -24, -12, 12, 24, 31.5]) lampPost(B, t, 16.3);
  for (const t of [-52, -30.5, 17.5]) tree(B, t, 16.2, 0.8);

  // ---- 街上的摆件 ----
  const pot = (t, s) => { B.add('plain', new THREE.CylinderGeometry(0.28, 0.2, 0.42, 8), M(t, 0.21, -s), '#a4583a'); B.add('leaf', new THREE.IcosahedronGeometry(0.36, 1), M(t, 0.62, -s), '#7fb357'); addColl(t - 0.3, t + 0.3, s - 0.3, s + 0.3); };
  const sack = (t, s) => { B.add('plain', new THREE.IcosahedronGeometry(0.32, 1), M(t, 0.26, -s, rnd() * 3, 0, 0, 1, 0.85, 1), '#cdbb95'); addColl(t - 0.3, t + 0.3, s - 0.3, s + 0.3); };
  const crate = (t, s, h = 0.5) => { B.add('wood', boxG(0.6, h, 0.6, 1), M(t, h / 2, -s, rnd() * 0.4)); addColl(t - 0.36, t + 0.36, s - 0.36, s + 0.36); };
  const bench = (t, s, w = 1.6) => { B.add('wood', boxG(w, 0.08, 0.36, 1), M(t, 0.42, -s)); for (const d of [-1, 1]) B.add('wood', boxG(0.08, 0.4, 0.3, 1), M(t + d * (w / 2 - 0.12), 0.2, -s)); addColl(t - w / 2, t + w / 2, s - 0.22, s + 0.22); };
  const chair = (t, s) => { B.add('plain', boxG(0.44, 0.06, 0.44, 1), M(t, 0.42, -s), '#c9a86a'); B.add('plain', boxG(0.44, 0.46, 0.05, 1), M(t, 0.66, -s - 0.2), '#b8955a'); for (const [a, b] of [[-0.18, -0.18], [0.18, -0.18], [-0.18, 0.18], [0.18, 0.18]]) B.add('plain', boxG(0.05, 0.42, 0.05, 1), M(t + a, 0.21, -s + b), '#a8864e'); addColl(t - 0.26, t + 0.26, s - 0.26, s + 0.26); };
  const table = (t, s) => { B.add('wood', boxG(0.9, 0.07, 0.9, 1), M(t, 0.62, -s)); B.add('wood', boxG(0.12, 0.6, 0.12, 1), M(t, 0.3, -s)); B.add('plain', new THREE.CylinderGeometry(0.1, 0.12, 0.16, 8), M(t + 0.15, 0.73, -s), '#e9e2d4'); addColl(t - 0.48, t + 0.48, s - 0.48, s + 0.48); };
  sack(-35.6, 21.5); sack(-34.9, 21.2); sack(-35.3, 20.7); crate(-31.6, 21.7, 0.42);
  chair(-28.7, 20.4); table(-27.4, 20.3); chair(-26.1, 20.4); chair(-27.4, 19.3);
  crate(-10, 21.8, 0.3); crate(-10, 21.8, 0.6); B.add('wood', boxG(0.12, 2.2, 0.3, 1), M(-5.6, 1.1, -22.2, 0, 0, 0.25)); B.add('wood', boxG(0.12, 2.2, 0.3, 1), M(-5.2, 1.1, -22.2, 0, 0, 0.2)); chair(-8.4, 20.9);
  bench(6.6, 21.6, 2.2); B.add('plain', new THREE.CylinderGeometry(0.46, 0.4, 0.62, 10), M(9.3, 0.31, -21.5), '#3a3440'); addColl(8.8, 9.8, 21, 22);
  for (const t of [-37.3, -24, -17.3, -4.7, 4.2, 16.8, 29.7]) pot(t, 21.9);
  bench(-44.5, 16.1); bench(5, 16.1, 1.4); bench(-15, 16.1, 1.4);
  pot(36, 18.6); pot(42, 18.6); bench(39, 16.2, 1.8);
  sack(-11.6, 71.6); sack(-10.9, 71.3); crate(11.7, 71.6); crate(12.3, 71.9, 0.35); sack(-5, 88); crate(5.2, 88.2, 0.45);

  // ---- 黄葛树广场（小学门口）----
  heroTree(B, BC, -13, 39.5);
  B.add('wood', boxG(0.12, 1.9, 0.12, 1), M(-7.1, 0.95, -36.2)); B.add('wood', boxG(0.12, 1.9, 0.12, 1), M(-5.1, 0.95, -36.2));
  const nb = new Pix(40, 26); nb.noise(0, 0, 40, 26, [P.wood0, P.wood], 3, 0.4);
  [[2, 2, 11, 9, P.paper1], [15, 3, 10, 12, P.paper], [27, 2, 11, 8, '#f3d6cf'], [4, 13, 9, 10, P.paper], [26, 12, 12, 11, P.paper1]].forEach(([x, y, w, h, c]) => { nb.rect(x, y, w, h, c); for (let j = y + 2; j < y + h - 1; j += 2) for (let i = x + 1; i < x + w - 2; i++) if (hash2(i, j) > 0.3) nb.set(i, j, P.ink1); nb.set(x + (w >> 1), y, P.red); });
  const board = new THREE.Mesh(new THREE.PlaneGeometry(2.4, 1.56), new THREE.MeshStandardMaterial({ map: texFrom(nb.done(), { repeat: false }), roughness: 0.9 }));
  board.position.set(-6.1, 1.35, -36.25); board.castShadow = true; town.add(board);
  B.add('tile', boxG(2.9, 0.1, 0.5, 1.2), M(-6.1, 2.2, -36.2)); addColl(-7.4, -4.8, 35.9, 36.6);
  addSign(town, '苏七周报', -6.1, 2.52, 36.1, 0.42);
  B.add('wood', boxG(0.9, 0.85, 0.7, 1), M(-7.8, 0.43, -34.4)); B.add('plain', boxG(0.92, 0.1, 0.72, 1), M(-7.8, 0.9, -34.4), P.red); addColl(-8.3, -7.3, 34, 34.8);
  bamboo(B, -34, 50); bamboo(B, -34, 59); bamboo(B, -44, 33); bamboo(B, -24, 68);

  // ---- 苏七小学（镇政府西南）----
  wallRun(B, -32, 47, -18.3, 47); wallRun(B, -13.7, 47, -6, 47); wallRun(B, -32, 47, -32, 65); wallRun(B, -6, 47, -6, 65); wallRun(B, -32, 65, -6, 65);
  gate(B, town, -16, 47, 4.4, '苏七小学', { post: 'white', h: 3.3, sign: { bg: '#f4ede0', fg: P.red0, border: P.red } });
  house(B, { t: -19, s: 56.5, w: 20, d: 7, h: 5.6, facade: 'school', side: 'white', flat: true });
  // ---- 镇政府（不可进）----
  house(B, { t: 15, s: 58, w: 16, d: 9, h: 7.2, facade: 'gov', side: 'white', flat: true });
  for (const t of [7.5, 22.5]) tree(B, t, 55.2, 0.9);

  // ---- 本地人集市（逢单日开）----
  const AWN = [[P.red, P.paper], [P.blu, P.paper], [P.gold, P.red0], [P.bam, P.paper]];
  [[-8, 73.8], [-14, 73.8], [8, 73.8], [14, 73.8], [-8, 86.3], [8, 86.3], [-14, 86.3], [14, 86.3]].forEach(([t, s], i) => stall(B, BMo, BMc, t, s, AWN[i % 4], 100 + i));
  REFS.npcSpots = { market: [[-11, 72.2, 0], [10.6, 72.2, 1], [-5.8, 84.7, 2], [-15.5, 84.7, 1], [4.4, 72.3, 2]], tourist: [[34.5, -31.2, 1], [43.2, -39.2, 0], [38.6, -35.2, 2]] };

  // ---- 牌坊：镇口 ----
  for (const t of [-4.2, -1.6, 1.6, 4.2]) { B.add('slab', boxG(0.46, t * t > 9 ? 4.1 : 5.0, 0.46, 1.4), M(t, (t * t > 9 ? 4.1 : 5.0) / 2, -94)); addColl(t - 0.35, t + 0.35, 93.6, 94.4); }
  B.add('wood', boxG(3.6, 0.34, 0.4, 1), M(0, 4.7, -94), P.red0); B.add('wood', boxG(9.2, 0.26, 0.36, 1), M(0, 3.75, -94));
  roof(B, 0, -94, 3.4, 1.2, 5.0, 'tile', 0.45, 0.36); for (const sg of [-1, 1]) roof(B, sg * 2.9, -94, 2.2, 1.0, 4.1, 'tile', 0.45, 0.36);
  addSign(town, '苏七镇', 0, 4.2, 93.62, 0.66, { bg: P.red0, fg: P.gold1, border: P.gold });

  // ---- 罗曼山庄：镇子边上，婚宴在这里 ----
  wallRun(B, -14, 104, -2.6, 104, 1.8); wallRun(B, 2.6, 104, 14, 104, 1.8); wallRun(B, -14, 104, -14, 122, 1.8); wallRun(B, 14, 104, 14, 122, 1.8); wallRun(B, -14, 122, 14, 122, 1.8);
  gate(B, town, 0, 104, 5.2, '罗曼山庄', { h: 3.9, post: 'plain', postCol: P.red, beamCol: P.red0, sign: { bg: P.red0, fg: P.gold1, border: P.gold } });
  for (const t of [-2.6, 2.6]) lantern(B, t, 3.0, -103.6, 1.3);
  const rr0 = house(B, { t: 0, s: 110.8, w: 16, d: 8, h: 5.4, facade: 'roman', eave: true, lanterns: 4 });
  for (const t of [-5.5, 5.5]) lantern(B, t, rr0.signY - 0.7, -109.9, 1.1);
  for (const [t, s] of [[-10.5, 107], [10.5, 107], [-10.5, 119], [10.5, 119]]) { B.add('leaf', new THREE.IcosahedronGeometry(0.8, 1), M(t, 0.6, -s, 0, 0, 0, 1.3, 0.8, 1), '#f1a4bf'); addColl(t - 0.9, t + 0.9, s - 0.9, s + 0.9); }

  // ---- 河南岸：住宅区，每人一屋六格地 ----
  const kinds = ['loubo', 'haijiao', 'guzi'];
  ROWS.forEach((front, ri) => HOUSE_T.forEach((t, hi) => {
    house(BS[ri], { t, s: front, w: 6.5, d: 5.5, h: 3.3, facade: 'house1', lanterns: (ri + hi) % 3 === 0 ? 2 : 0 });
    const mine = ri === 0 && t === 9;
    for (let r = 0; r < 2; r++) for (let c = 0; c < 3; c++) {
      const pt = t + (c - 1) * 1.6, ps = front - 1.45 - r * 1.75;
      B.add('soil', boxG(1.34, 0.16, 1.34, 1.34), M(pt, 0.08, -ps));
      if (!mine && hash2(hi * 7 + c, ri * 5 + r) > 0.18) REFS.crops.push({ t: pt, s: ps, kind: kinds[Math.floor(hash2(hi + r, c + ri) * 3)], st: 1 + Math.floor(hash2(c * 3 + hi, r + 9) * 3) });
    }
  }));
  for (const t of [-10, 10]) lampPost(B, t, -16.3);
  for (const t of [-40, -22, 14, 30, -64]) tree(B, t, -16.2, 0.85);

  // ---- 游客集市：天天开 ----
  [32, 36.5, 41, 45.5].forEach((t, i) => { stall(B, B, null, t, -29, AWN[(i + 1) % 4], 200 + i); stall(B, B, null, t, -37.2, AWN[(i + 3) % 4], 300 + i); });

  // ---- 月老庙：外殿（内殿只有许了愿的人看得到，样机不做）----
  wallRun(B, -70, -41, -62.3, -41, 1.7, 'redwall'); wallRun(B, -57.7, -41, -50, -41, 1.7, 'redwall');
  wallRun(B, -70, -41, -70, -25, 2.3, 'redwall'); wallRun(B, -50, -41, -50, -25, 2.3, 'redwall'); wallRun(B, -70, -25, -50, -25, 2.3, 'redwall');
  gate(B, town, -60, -41, 4.4, '月老庙', { h: 3.4, post: 'plain', postCol: P.red0, beamCol: P.red0, sign: { bg: P.red0, fg: P.gold1, border: P.gold } });
  house(B, { t: -60, s: -34, w: 12, d: 6.5, h: 4.2, facade: 'temple', side: 'redwall', lanterns: 4, rise: 0.4 });
  tree(B, -65.5, -37.6, 1.05);
  for (let k = 0; k < 22; k++) { const a = k * 2.4, r = rr(0.5, 1.3), L = rr(0.5, 1.1); B.add('plain', boxG(0.03, L, 0.03, 1), M(-65.5 + Math.cos(a) * r, 2.2 - L / 2, 37.6 + Math.sin(a) * r), P.red); }
  B.add('plain', new THREE.CylinderGeometry(0.42, 0.34, 0.7, 8), M(-55.8, 0.35, 37.2), '#6d5a3e'); addColl(-56.3, -55.3, -37.7, -36.7);
  B.add('wood', boxG(1.8, 1.2, 0.12, 1), M(-54, 1.1, 38.9), P.red0); B.add('wood', boxG(0.1, 1.7, 0.1, 1), M(-54.8, 0.85, 38.95)); B.add('wood', boxG(0.1, 1.7, 0.1, 1), M(-53.2, 0.85, 38.95)); addColl(-55, -53, -39.1, -38.7);

  // ---- 树：地图边上一圈，空地上撒一些 ----
  const inArea = (t, s, pad) => AREAS.some(a => t > a.t0 - pad && t < a.t1 + pad && s > a.s0 - pad && s < a.s1 + pad);
  const inColl = (t, s, pad) => COLL.some(c => t > c.t0 - pad && t < c.t1 + pad && s > c.s0 - pad && s < c.s1 + pad);
  const ok = (t, s) => Math.abs(s) > RIVER + 2.4 && !inArea(t, s, 0.9) && !inColl(t, s, 1.4);
  for (let t = T0 + 2; t < T1 - 1; t += 4.6) for (const s of [S1 - 2.5, S0 + 2.5]) { const tt = t + rr(-1, 1), ss = s + rr(-1, 1); if (ok(tt, ss)) tree(B, tt, ss, rr(1, 1.3)); }
  for (let s = S0 + 5; s < S1 - 3; s += 4.6) for (const t of [T0 + 2.5, T1 - 2.5]) { const tt = t + rr(-1, 1), ss = s + rr(-1, 1); if (ok(tt, ss)) tree(B, tt, ss, rr(1, 1.3)); }
  for (let n = 0, k = 0; n < 95 && k < 3000; k++) { const t = rr(T0 + 4, T1 - 4), s = rr(S0 + 4, S1 - 4); if (ok(t, s)) { tree(B, t, s, rr(0.8, 1.25)); n++; } }
  for (let n = 0, k = 0; n < 30 && k < 2000; k++) { const t = rr(T0 + 4, T1 - 4), s = rr(S0 + 4, S1 - 4); if (ok(t, s)) { B.add('leaf', new THREE.IcosahedronGeometry(rr(0.5, 0.8), 1), M(t, 0.45, -s, 0, 0, 0, 1.3, 0.75, 1), rnd() > 0.5 ? '#f1a4bf' : '#8fc265'); n++; } }

  B.flush(town);
  const rowA = BR.flush(town, { clone: true }), row1 = BS[0].flush(town, { clone: true }), row2 = BS[1].flush(town, { clone: true });
  REFS.fadeGroups = [
    { mats: [...rowA.map(m => m.material), ...REFS.rowSigns.map(m => m.material)], test: (t, s) => s > 29.2 && s < 52 && t > -46 && t < 32 },
    { mats: row1.map(m => m.material), test: (t, s) => s > -24.8 && s < -12 && t > -40 && t < 26 },
    { mats: row2.map(m => m.material), test: (t, s) => s > -43.2 && s < -35 && t > -40 && t < 26 },
  ];
  REFS.marketOpen = new THREE.Group(); REFS.marketClosed = new THREE.Group(); town.add(REFS.marketOpen, REFS.marketClosed);
  BMo.flush(REFS.marketOpen); BMc.flush(REFS.marketClosed);
  const canopyMat = MAT('leaf').clone(); canopyMat.transparent = true;
  REFS.canopy = BC.flush(town, { mat: canopyMat })[0];
  REFS.town = town; return town;
}
