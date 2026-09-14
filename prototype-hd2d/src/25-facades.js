// =====================================================================
// 立面：川西民居，白墙穿斗木架、小青瓦。每种立面画一次，按尺寸缓存
// =====================================================================
const FPPU = 12;
const facadeCache = new Map();
function facadeTex(kind, w, h) {
  const key = kind + '|' + w + '|' + h;
  if (facadeCache.has(key)) return facadeCache.get(key);
  const W = Math.round(w * FPPU), H = Math.round(h * FPPU), p = new Pix(W, H);
  FACADE[kind](p, W, H);
  const tex = texFrom(p.done(), { repeat: false });
  facadeCache.set(key, tex); return tex;
}
const plaster = (p, x, y, w, h, seed = 3) => p.noise(x, y, w, h, [P.paper0, P.paper, P.paper, P.paper1], seed, 0.55);
function vpost(p, x, y0, y1) { for (let y = y0; y < y1; y++) { p.set(x, y, P.wood0); p.set(x + 1, y, P.wood); } }
function hbeam(p, x0, x1, y, th = 2) { for (let x = x0; x < x1; x++) for (let k = 0; k < th; k++) p.set(x, y + k, k === 0 ? P.wood1 : P.wood0); }
function lattice(p, x, y, w, h, paper = P.paper1, bar = P.wood) {
  p.rect(x, y, w, h, P.wood0); p.rect(x + 1, y + 1, w - 2, h - 2, paper);
  for (let i = x + 1; i < x + w - 1; i++) for (let j = y + 1; j < y + h - 1; j++) if ((i - x) % 3 === 0 || (j - y) % 3 === 0) p.set(i, j, bar);
}
function planks(p, x, y, w, h) {
  for (let i = 0; i < w; i++) for (let j = 0; j < h; j++) p.set(x + i, y + j, i % 3 === 2 ? P.wood0 : (Math.floor(i / 3) % 2 ? P.wood : P.wood1));
  p.specks(x, y, w, h, P.wood0, 0.05);
}
function interior(p, x, y, w, h) { p.noise(x, y, w, h, ['#1a1420', '#221a28', '#2c2231'], 5, 0.4); for (let i = x; i < x + w; i++) p.set(i, y + h - 1, P.wood0); }
function door2(p, cx, yb, w, h, col = P.wood, dark = P.wood0) {
  const x = cx - (w >> 1), y = yb - h;
  p.rect(x - 1, y - 1, w + 2, h + 1, P.wood0); p.rect(x, y, w, h, col);
  for (let j = y; j < yb; j++) p.set(cx, j, dark);
  for (let j = y + 2; j < yb - 1; j += 4) { p.set(x + 1, j, dark); p.set(x + w - 2, j, dark); }
  p.set(cx - 2, y + (h >> 1), P.gold); p.set(cx + 1, y + (h >> 1), P.gold);
}
const couplet = (p, x, y, h) => { p.rect(x, y, 2, h, P.red); p.set(x, y, P.red0); p.set(x + 1, y + h - 1, P.red0); };
function xi(p, cx, cy, col = P.red) { // 囍，7×7 像素
  ['xxx.xxx', '.x...x.', 'xxx.xxx', 'x.x.x.x', 'xxx.xxx', '.x...x.', 'xxx.xxx'].forEach((r, j) => [...r].forEach((ch, i) => { if (ch === 'x') p.set(cx - 3 + i, cy - 3 + j, col); }));
}
const GOODS = [P.red, P.gold, P.bam1, P.paper1, P.pink, P.red1, P.pur1];

const SHOP_INSIDE = {
  seed(p, x, y, w, h) {
    for (const sy of [y + 3, y + 9]) { for (let i = x; i < x + w; i++) p.set(i, sy, P.wood1); for (let i = x + 1; i < x + w - 2; i += 3) p.rect(i, sy - 2, 2, 2, GOODS[(i * 7 + sy) % GOODS.length]); }
    for (let i = x + 1; i < x + w - 4; i += 6) { p.rect(i, y + h - 5, 4, 4, P.paper0); p.rect(i + 1, y + h - 6, 2, 1, P.paper); p.set(i + 1, y + h - 4, P.gold); }
  },
  tea(p, x, y, w, h) {
    for (let i = x + 2; i < x + w - 6; i += 9) { p.rect(i, y + h - 6, 6, 1, P.wood1); p.set(i, y + h - 5, P.wood0); p.set(i + 5, y + h - 5, P.wood0); p.set(i + 2, y + h - 7, P.stone1); p.set(i + 3, y + h - 7, P.stone1);
      p.rect(i - 2, y + h - 5, 1, 4, P.bam1); p.rect(i + 7, y + h - 5, 1, 4, P.bam1); p.set(i - 2, y + h - 6, P.gold); p.set(i + 7, y + h - 6, P.gold); }
    for (let i = x + 3; i < x + w; i += 10) { p.set(i, y + 1, P.red); p.set(i, y + 2, P.red1); }
  },
  beef(p, x, y, w, h) {
    const cx = x + (w >> 1), by = y + h - 3;
    for (let i = -5; i <= 5; i++) { p.set(cx + i, by - 4, P.stone1); p.set(cx + i, by, P.stone0); for (let j = by - 3; j < by; j++) p.set(cx + i, j, Math.abs(i) < 5 ? '#c98a4b' : P.stone0); }
    for (let k = 0; k < 10; k++) p.set(cx - 4 + ((k * 3) % 9), by - 6 - (k % 4) * 2, P.paper1);
    for (let i = x + 1; i < x + w - 1; i++) if (Math.abs(i - cx) > 7) { p.set(i, y + h - 4, P.wood1); if ((i - x) % 7 === 0) { p.set(i, y + h - 3, P.wood0); p.set(i, y + h - 2, P.wood0); } }
  },
  carp(p, x, y, w, h) {
    for (let k = 0; k < 4; k++) for (let j = 0; j < h - 2; j++) p.set(x + 2 + k * 2 + (j >> 2), y + 1 + j, k % 2 ? P.wood1 : P.wood);
    const cx = x + w - 10, by = y + h - 2;
    for (let j = 0; j < 7; j++) { p.set(cx, by - j, P.wood1); } for (let i = 0; i < 5; i++) p.set(cx + i, by - 3, P.wood1); p.set(cx + 4, by - 1, P.wood1); p.set(cx + 4, by - 2, P.wood1);
    for (let i = x + (w >> 1) - 4; i < x + (w >> 1) + 4; i++) p.set(i, by - 4, P.wood1);
  },
};

function shopFront(p, W, H, v) {
  plaster(p, 0, 0, W, H, 3);
  const gH = Math.round(H * 0.56), fy = H - gH;
  lattice(p, (W - Math.round(W * 0.42)) >> 1, Math.round(fy * 0.22), Math.round(W * 0.42), Math.round(fy * 0.52));
  const ox = 2, oy = fy + 2, ow = W - 4, oh = gH - 4;
  if (v === 'closed') planks(p, ox, oy, ow, oh);
  else { interior(p, ox, oy, ow, oh); SHOP_INSIDE[v](p, ox, oy, ow, oh); planks(p, ox, H - 7, ow, 5); }
  vpost(p, 0, 0, H); vpost(p, W - 2, 0, H); vpost(p, Math.round(W / 3) - 1, fy, H); vpost(p, Math.round(2 * W / 3) - 1, fy, H);
  hbeam(p, 0, W, 0, 2); hbeam(p, 0, W, fy - 1, 3); hbeam(p, 0, W, H - 2, 2);
}
function homeFront(p, W, H, { two = true, red = false, wide = false } = {}) {
  plaster(p, 0, 0, W, H, red ? 9 : 5);
  const fy = two ? H - Math.round(H * 0.56) : 0, cx = W >> 1;
  if (two) {
    const lw = Math.round(W * 0.26), lh = Math.round(fy * 0.5);
    lattice(p, Math.round(W * 0.14), Math.round(fy * 0.24), lw, lh, red ? '#fbe1d6' : P.paper1);
    lattice(p, W - Math.round(W * 0.14) - lw, Math.round(fy * 0.24), lw, lh, red ? '#fbe1d6' : P.paper1);
    if (red) { xi(p, Math.round(W * 0.14) + (lw >> 1), Math.round(fy * 0.24) + (lh >> 1)); xi(p, W - Math.round(W * 0.14) - (lw >> 1) - 1, Math.round(fy * 0.24) + (lh >> 1)); }
  }
  const dw = wide ? 18 : 12, dh = Math.round((H - fy) * 0.68);
  door2(p, cx, H - 2, dw, dh, red ? P.red : P.wood, red ? P.red0 : P.wood0);
  if (red || wide) for (let j = H - 2 - dh + 2; j < H - 3; j += 3) for (let i = cx - (dw >> 1) + 2; i < cx + (dw >> 1) - 1; i += 3) if (i !== cx) p.set(i, j, P.gold);
  couplet(p, cx - (dw >> 1) - 4, H - 2 - dh, dh - 2); couplet(p, cx + (dw >> 1) + 2, H - 2 - dh, dh - 2);
  const ww = 9, wy = H - 2 - dh + 3;
  lattice(p, Math.round(W * 0.18) - 4, wy, ww, ww, red ? '#fbe1d6' : P.paper1); lattice(p, W - Math.round(W * 0.18) - 5, wy, ww, ww, red ? '#fbe1d6' : P.paper1);
  if (red) { xi(p, Math.round(W * 0.18), wy + 4); xi(p, W - Math.round(W * 0.18) - 1, wy + 4); }
  vpost(p, 0, 0, H); vpost(p, W - 2, 0, H); vpost(p, cx - (dw >> 1) - 7, fy, H); vpost(p, cx + (dw >> 1) + 5, fy, H);
  hbeam(p, 0, W, 0, 2); if (two) hbeam(p, 0, W, fy - 1, 3); hbeam(p, 0, W, H - 2, 2);
}

const FACADE = {
  seed: (p, W, H) => shopFront(p, W, H, 'seed'),
  tea: (p, W, H) => shopFront(p, W, H, 'tea'),
  beef: (p, W, H) => shopFront(p, W, H, 'beef'),
  carp: (p, W, H) => shopFront(p, W, H, 'carp'),
  closed: (p, W, H) => shopFront(p, W, H, 'closed'),
  house2: (p, W, H) => homeFront(p, W, H, { two: true }),
  house1: (p, W, H) => homeFront(p, W, H, { two: false }),
  couple: (p, W, H) => homeFront(p, W, H, { two: true, red: true }),
  roman: (p, W, H) => homeFront(p, W, H, { two: true, red: true, wide: true }),
  school(p, W, H) {
    p.noise(0, 0, W, H, ['#e3d2ad', '#ecdcba', '#f3e6c8'], 4, 0.5);
    for (let x = 0; x < W; x++) { p.set(x, 1, P.red1); p.set(x, 2, P.red1); p.set(x, H - 1, P.stone0); p.set(x, H - 2, P.stone); }
    const cx = W >> 1;
    for (const wy of [6, Math.round(H * 0.55)]) for (let x = 6; x < W - 10; x += 14) {
      if (wy > H * 0.5 && Math.abs(x + 4 - cx) < 12) continue;
      p.rect(x, wy, 10, 10, P.paper1); p.rect(x + 1, wy + 1, 8, 8, P.sea1); p.rect(x + 1, wy + 5, 8, 1, P.paper1); p.set(x + 2, wy + 2, '#ffffff');
    }
    p.rect(cx - 7, H - 22, 14, 20, P.paper1); p.rect(cx - 6, H - 21, 12, 19, P.blu0); for (let j = H - 21; j < H - 2; j++) p.set(cx, j, P.paper1);
  },
  gov(p, W, H) {
    p.noise(0, 0, W, H, ['#ddd8cf', '#e7e3dc', '#efece6'], 6, 0.5);
    for (let x = 0; x < W; x++) { p.set(x, 0, P.stone); p.set(x, 1, P.stone1); p.set(x, H - 1, P.stone0); p.set(x, H - 2, P.stone0); }
    const cx = W >> 1;
    for (let r = 0; r < 3; r++) for (let x = 5; x < W - 8; x += 12) {
      const wy = 5 + r * Math.round((H - 10) / 3);
      if (r === 2 && Math.abs(x + 4 - cx) < 12) continue;
      p.rect(x, wy, 8, 9, '#f6f4ef'); p.rect(x + 1, wy + 1, 6, 7, P.blu0); p.set(x + 2, wy + 2, P.blu1);
    }
    p.rect(cx - 8, H - 20, 16, 18, P.stone1); p.rect(cx - 6, H - 18, 12, 16, P.sea0); p.rect(cx - 1, H - 18, 2, 16, P.stone1);
  },
  temple(p, W, H) {
    p.noise(0, 0, W, H, [P.red0, P.red, P.red], 8, 0.5);
    for (let x = 0; x < W; x++) { p.set(x, 0, P.ink); p.set(x, 1, P.gold0); p.set(x, 2, P.ink); p.set(x, H - 1, P.stone0); p.set(x, H - 2, P.stone); p.set(x, H - 3, P.stone); }
    for (let x = 4; x < W; x += 6) p.set(x, 1, P.gold);
    const n = 3, dw = Math.round((W - 16) / n) - 4, dh = H - 12;
    for (let k = 0; k < n; k++) {
      const x = 8 + k * (dw + 4) + 2, y = 6;
      p.rect(x, y, dw, dh, P.gold0); p.rect(x + 1, y + 1, dw - 2, dh - 2, P.red0);
      for (let i = x + 2; i < x + dw - 2; i++) for (let j = y + 2; j < y + Math.round(dh * 0.55); j++) if ((i - x) % 3 === 0 || (j - y) % 3 === 0) p.set(i, j, P.gold);
      p.rect(x + 2, y + Math.round(dh * 0.62), dw - 4, dh - Math.round(dh * 0.62) - 3, P.red);
    }
  },
};
