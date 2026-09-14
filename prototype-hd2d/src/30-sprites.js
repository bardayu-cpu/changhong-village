// =====================================================================
// 精灵：全部占位。宾客按美术包 8 个预设里的 3 号画（中长发、米色针织、金耳饰）
// 头身比向现有阿鱼立绘靠（约 1:3），不是美术包提案的 1:2
// =====================================================================
const GUEST_FRONT = [
  '................', '......oooo......', '....ooHHHHoo....', '...oHHHiiHHHo...', '..oHHHHHHHHHHo..', '..oHHhhhhhhHHo..',
  '..oHhsssssshHo..', '..oHssssssssHo..', '..oHsessssesHo..', '..oHsessssesHo..', '..oHbssmmssbHo..', '..oHgSssssSgHo..',
  '...oHHoSSoHHo...', '...okkkkkkkko...', '..okkkkkkkkkko..', '..oKkkkkkkkkKo..', '..oKkkkkkkkkKo..', '..oKkKkkkkKkKo..',
  '..oKkKkkkkKkKo..', '..osKKKKKKKKso..', '...oppppppppo...', '...oppppppppo...', '...opppPPpppo...', '...opppPPpppo...',
  '...opppoopppo...', '...opppoopppo...', '...opppoopppo...', '...oPPPooPPPo...', '...oPPPooPPPo...', '...offfoofffo...',
  '..offffooffffo..', '...oooo..oooo...',
];
const GUEST_BACK = GUEST_FRONT.map((r, j) => ({
  5: '..oHHHHHHHHHHo..', 6: '..oHHHHHHHHHHo..', 7: '..oHHHHHHHHHHo..', 8: '..oHHHhHHhHHHo..', 9: '..oHHHHHHHHHHo..',
  10: '..oHHhHHHHhHHo..', 11: '..oHHHHHHHHHHo..', 12: '...oHHHHHHHHo...',
}[j] || r));
const GUEST_SIDE = [
  '................', '......oooo......', '....ooHHHHo.....', '...oHHHiiHHo....', '..oHHHHHHHHHo...', '..oHHHHHHHhhho..',
  '..oHHHHHHhssso..', '..oHHHHHHsssso..', '..oHHHHHHsseso..', '..oHHHHHHsseso..', '..oHHHHHgbssso..', '..oHHHHHHsSSo...',
  '...oHHHHoSSo....', '....okkkkkko....', '...okkkkkkkko...', '...okkKKkkkko...', '...okkKKkkkko...', '...okkKKkkkko...',
  '...okkKKkkkko...', '...oKKsKKKKKo...', '....oppppppo....',
];
const PAL_GUEST = { o: '#2C2438', H: '#4a3226', h: '#3a261d', i: '#6d4a38', s: '#f1c9a1', S: '#d7a17c', e: '#1E1A2A', m: '#b4574a', b: '#E8746A', g: '#D4AF37', k: '#E8DDD0', K: '#B8A88E', p: '#3A6491', P: '#1F3A5C', f: '#5A4E68' };
const PAL_NPC = [
  { ...PAL_GUEST, H: '#2b2230', h: '#1d1722', i: '#453a4f', g: '#2b2230', k: '#4A6FA5', K: '#2E4A7A', p: '#2C2438', P: '#1E1A2A', f: '#46291d' },
  { ...PAL_GUEST, H: '#9a97a3', h: '#7d7a86', i: '#c4c1cb', g: '#9a97a3', s: '#e6b894', k: '#6b432d', K: '#46291d', p: '#3E3160', P: '#2b2143', f: '#2C2438' },
  { ...PAL_GUEST, H: '#3a261d', h: '#2a1a14', k: '#C0392B', K: '#8C2F27', p: '#5A4E68', P: '#3b3345' },
];

function mapPix(p, rows, pal, ox = 0, oy = 0) { rows.forEach((r, j) => [...r].forEach((ch, i) => { if (ch !== '.' && pal[ch]) p.set(ox + i, oy + j, pal[ch]); })); }
function liftLeg(rows, x0, x1) { // 正面走路：一条腿抬一格
  const out = rows.map(r => [...r]);
  for (let y = 24; y < 32; y++) for (let x = x0; x <= x1; x++) out[y][x] = y < 31 ? rows[y + 1][x] : '.';
  return out.map(r => r.join(''));
}
function sideLegs(p, phase, pal) {
  const legs = phase === 0 ? [[0, pal.P, 6], [0, pal.p, 7]] : phase === 1 ? [[-1, pal.P, 6], [1, pal.p, 7]] : [[1, pal.P, 6], [-1, pal.p, 7]];
  for (const [dir, col, bx] of legs) {
    for (let y = 21; y <= 28; y++) { const x = bx + Math.round(dir * (y - 21) / 3.5); p.set(x - 1, y, pal.o); p.set(x, y, col); p.set(x + 1, y, col); p.set(x + 2, y, col); p.set(x + 3, y, pal.o); }
    const fx = bx + Math.round(dir * 2);
    for (let i = -1; i <= 4; i++) p.set(fx + i, 29, (i === -1 || i === 4) ? pal.o : pal.f);
    for (let i = -1; i <= 5; i++) p.set(fx + i, 30, (i === -1 || i === 5) ? pal.o : pal.f);
    for (let i = -1; i <= 5; i++) p.set(fx + i, 31, pal.o);
  }
}
function humanFrames(prefix, pal) {
  const out = [];
  const front = [GUEST_FRONT, liftLeg(GUEST_FRONT, 8, 12), liftLeg(GUEST_FRONT, 3, 7)];
  const back = [GUEST_BACK, liftLeg(GUEST_BACK, 8, 12), liftLeg(GUEST_BACK, 3, 7)];
  front.forEach((rows, k) => { const p = new Pix(16, 32); mapPix(p, rows, pal); out.push([`${prefix}_down${k}`, p.done()]); });
  back.forEach((rows, k) => { const p = new Pix(16, 32); mapPix(p, rows, pal); out.push([`${prefix}_up${k}`, p.done()]); });
  for (let k = 0; k < 3; k++) { const p = new Pix(16, 32); sideLegs(p, k, pal); mapPix(p, GUEST_SIDE, pal); out.push([`${prefix}_side${k}`, p.done()]); }
  return out;
}

function ell(p, cx, cy, rx, ry, col) { for (let y = Math.floor(cy - ry); y <= Math.ceil(cy + ry); y++) for (let x = Math.floor(cx - rx); x <= Math.ceil(cx + rx); x++) { const dx = (x + 0.5 - cx) / rx, dy = (y + 0.5 - cy) / ry; if (dx * dx + dy * dy <= 1) p.set(x, y, col); } }
function corgi(phase) {
  const p = new Pix(24, 16), tan = '#d98c3f', tanS = '#b36a2a', wh = '#fff3e0', whS = '#e3d1b6';
  const L = phase ? [[4, 12], [7, 13], [13, 12], [16, 13]] : [[5, 13], [7, 12], [14, 13], [16, 12]];
  L.forEach(([x, y]) => { p.rect(x, 10, 2, y - 9, tanS); p.rect(x, y, 2, 1, wh); });
  ell(p, 10.5, 8.5, 7.5, 3.6, tan); ell(p, 11, 10.3, 6, 1.6, wh); p.rect(3, 6, 2, 2, tan);
  ell(p, 18.5, 6, 3.7, 3.4, tan); ell(p, 20.6, 7.4, 2.2, 1.5, wh); ell(p, 17.5, 9, 2.3, 1.6, wh);
  p.rect(16, 1, 2, 3, tan); p.set(16, 0, tan); p.rect(19, 1, 2, 3, tan); p.set(20, 0, tan); p.set(17, 2, '#e8a0a0'); p.set(19, 2, '#e8a0a0');
  p.set(19, 5, '#1E1A2A'); p.set(22, 6, '#1E1A2A'); p.set(9, 6, tanS); p.set(12, 6, tanS);
  p.outline('#3a2419'); return p.done();
}
function cat(kind, pose) {
  const C = {
    luoluo: ['#e3b46b', '#c28a45', '#f6dba8'], tiantian: ['#e0ae62', '#bd8640', '#f3d49b'], qiuqiu: ['#a48666', '#6e5540', '#d9c4a6'],
  }[kind];
  const [base, shade, light] = C, p = new Pix(18, 14);
  if (pose === 'sleep') {
    ell(p, 8.5, 9, 7, 3.6, base); ell(p, 13.2, 8, 3, 2.6, base); p.set(12, 5, base); p.set(15, 5, base); p.set(12, 6, shade); p.set(15, 6, shade);
    for (let x = 3; x < 12; x++) p.set(x, 12, shade); p.set(13, 8, '#4a3226'); p.set(14, 8, '#4a3226');
    if (kind === 'luoluo') for (let k = 0; k < 14; k++) p.set(2 + Math.floor(hash2(k, 4) * 14), 5 + Math.floor(hash2(k, 5) * 3), light);
  } else if (pose === 'sit') {
    ell(p, 8.5, 9.5, 4.2, 3.8, base); ell(p, 9, 5, 3.4, 3, base); p.rect(6, 1, 1, 2, base); p.set(6, 3, base); p.rect(11, 1, 1, 2, base); p.set(11, 3, base);
    ell(p, 9, 10.5, 2, 2.4, light); p.set(7, 5, '#2C2438'); p.set(10, 5, '#2C2438'); p.set(8, 6, '#E8746A'); p.set(9, 6, '#E8746A');
    for (let x = 12; x < 16; x++) p.set(x, 12, shade); p.set(15, 11, shade);
    if (kind === 'qiuqiu') { p.set(8, 3, shade); p.set(9, 3, shade); p.set(10, 3, shade); ell(p, 8.5, 9, 1.4, 1.4, shade); p.set(8, 9, base); }
  } else {
    const L = pose === 1 ? [[4, 1], [6, 0], [11, 1], [13, 0]] : [[5, 0], [6, 1], [12, 0], [13, 1]];
    L.forEach(([x, d]) => p.rect(x, 9, 1, 3 - d, shade));
    ell(p, 8.5, 8, 5.4, 2.6, base); ell(p, 14, 5.2, 2.8, 2.6, base); p.set(12, 2, base); p.set(12, 3, base); p.set(15, 2, base); p.set(15, 3, base);
    p.set(15, 5, '#2C2438'); p.set(17, 6, '#E8746A'); for (let y = 3; y < 8; y++) p.set(2 + (y > 5 ? 1 : 0), y, shade);
    if (kind === 'qiuqiu') for (let x = 5; x < 12; x += 2) { p.set(x, 6, shade); p.set(x, 7, shade); }
  }
  p.outline(kind === 'qiuqiu' ? '#33271e' : '#5a3a1e'); return p.done();
}
function crop(kind, st) {
  const p = new Pix(16, 16), g0 = P.bam0, g1 = P.bam, g2 = P.bam1;
  if (kind === 'loubo') {
    if (st === 1) { p.set(7, 13, g1); p.set(8, 13, g1); p.set(6, 12, g2); p.set(9, 12, g2); }
    else { const n = st === 2 ? 4 : 6; for (let k = 0; k < n; k++) { const x = 8 + Math.round((k - n / 2) * 1.6); for (let y = 14 - (st === 2 ? 5 : 8); y < 14; y++) p.set(x + (y < 10 ? (k < n / 2 ? -1 : 1) : 0), y, k % 2 ? g1 : g2); }
      if (st === 3) { ell(p, 8, 13.5, 2.6, 1.8, P.paper1); p.set(7, 13, '#f0c6cf'); } }
  } else if (kind === 'haijiao') {
    const hgt = st === 1 ? 3 : st === 2 ? 7 : 9;
    for (let y = 14 - hgt; y < 15; y++) p.set(8, y, g0);
    if (st > 1) { ell(p, 8, 14 - hgt + 3, st === 2 ? 3.2 : 4.6, st === 2 ? 2.4 : 3.2, g1); ell(p, 7, 14 - hgt + 2, 2, 1.4, g2); }
    else { p.set(7, 12, g2); p.set(9, 12, g2); }
    if (st === 2) { p.set(6, 7, P.paper1); p.set(10, 8, P.paper1); }
    if (st === 3) [[5, 8], [10, 7], [8, 10], [12, 9], [4, 10]].forEach(([x, y]) => { p.set(x, y, P.red); p.set(x, y + 1, P.red); p.set(x, y + 2, P.red0); });
  } else {
    const hgt = st === 1 ? 3 : st === 2 ? 8 : 10, col = st === 3 ? P.gold : g1, top = st === 3 ? P.gold1 : g2;
    for (const x of [5, 7, 9, 11]) for (let y = 14 - hgt; y < 15; y++) p.set(x + (y < 14 - hgt + 3 && st === 3 ? 1 : 0), y, y < 14 - hgt + 3 ? top : col);
    if (st === 3) for (const x of [6, 8, 10, 12]) { p.set(x, 14 - hgt + 1, P.gold0); p.set(x, 14 - hgt + 2, P.gold0); }
  }
  p.outline('#263d23'); return p.done();
}
function leafMark() { const p = new Pix(11, 11); ell(p, 5.5, 5.5, 3.2, 4.6, P.gold1); for (let y = 2; y < 10; y++) p.set(5, y, P.gold); p.set(6, 3, '#ffffff'); p.outline(P.gold0); return p.done(); }

// 打包成一张图集
function buildAtlas() {
  const frames = [...humanFrames('guest', PAL_GUEST)];
  PAL_NPC.forEach((pal, i) => frames.push(...humanFrames('npc' + i, pal)));
  frames.push(['corgi0', corgi(0)], ['corgi1', corgi(1)]);
  frames.push(['luoluo_sleep', cat('luoluo', 'sleep')], ['luoluo_sit', cat('luoluo', 'sit')], ['tiantian0', cat('tiantian', 0)], ['tiantian1', cat('tiantian', 1)], ['tiantian_sit', cat('tiantian', 'sit')], ['qiuqiu_sit', cat('qiuqiu', 'sit')]);
  for (const k of ['loubo', 'haijiao', 'guzi']) for (let s = 1; s <= 3; s++) frames.push([`${k}${s}`, crop(k, s)]);
  frames.push(['leaf', leafMark()]);
  const AW = 512; let x = 0, y = 0, rowH = 0; const FR = {};
  for (const [name, c] of frames) { if (x + c.width > AW) { x = 0; y += rowH + 1; rowH = 0; } FR[name] = { x, y, w: c.width, h: c.height, c }; x += c.width + 1; rowH = Math.max(rowH, c.height); }
  const AH = 256; const [ac, ag] = makeCanvas(AW, AH);
  for (const f of Object.values(FR)) { ag.drawImage(f.c, f.x, f.y); delete f.c; }
  const tex = texFrom(ac, { repeat: false, mip: false });
  return { tex, FR, AW, AH };
}
