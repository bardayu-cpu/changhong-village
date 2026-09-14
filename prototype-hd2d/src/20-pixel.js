// =====================================================================
// 像素贴图：全部在 canvas 上逐像素画，放大用最近邻，缩小用 mipmap
// 单张不超过 1024（微信小游戏渲染建议）
// =====================================================================
const RGBC = {};
const rgb = (h) => RGBC[h] || (RGBC[h] = hexRGB(h));

function makeCanvas(w, h) {
  const c = document.createElement('canvas'); c.width = w; c.height = h;
  const g = c.getContext('2d'); g.imageSmoothingEnabled = false; return [c, g];
}
function texFrom(canvas, { repeat = true, mip = true } = {}) {
  const t = new THREE.CanvasTexture(canvas);
  t.colorSpace = THREE.SRGBColorSpace;
  t.magFilter = THREE.NearestFilter;
  t.minFilter = mip ? THREE.LinearMipmapLinearFilter : THREE.NearestFilter;
  t.generateMipmaps = mip; t.anisotropy = 4;
  if (repeat) t.wrapS = t.wrapT = THREE.RepeatWrapping;
  return t;
}
class Pix {
  constructor(w, h) { [this.c, this.g] = makeCanvas(w, h); this.w = w; this.h = h; this.img = this.g.createImageData(w, h); this.d = this.img.data; }
  set(x, y, hex, a = 255) {
    x |= 0; y |= 0; if (x < 0 || y < 0 || x >= this.w || y >= this.h) return;
    const c = typeof hex === 'string' ? rgb(hex) : hex, i = (y * this.w + x) * 4;
    this.d[i] = c[0]; this.d[i + 1] = c[1]; this.d[i + 2] = c[2]; this.d[i + 3] = a;
  }
  alpha(x, y) { return (x < 0 || y < 0 || x >= this.w || y >= this.h) ? 0 : this.d[(y * this.w + x) * 4 + 3]; }
  rect(x, y, w, h, hex) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) this.set(x + i, y + j, hex); }
  noise(x, y, w, h, cols, seed = 1, scale = 0.35) {
    for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) {
      const n = fbm((x + i) * scale + seed * 13.1, (y + j) * scale) + (hash2(x + i + seed * 71, y + j) - 0.5) * 0.25;
      this.set(x + i, y + j, cols[Math.max(0, Math.min(cols.length - 1, Math.floor(n * cols.length)))]);
    }
  }
  specks(x, y, w, h, hex, dens, seed = 3) { for (let j = 0; j < h; j++) for (let i = 0; i < w; i++) if (hash2(x + i + seed * 977, y + j - seed * 131) < dens) this.set(x + i, y + j, hex); }
  outline(hex) { // 给不透明像素描一圈外框
    const add = [];
    for (let y = 0; y < this.h; y++) for (let x = 0; x < this.w; x++) if (!this.alpha(x, y) && (this.alpha(x - 1, y) || this.alpha(x + 1, y) || this.alpha(x, y - 1) || this.alpha(x, y + 1))) add.push([x, y]);
    add.forEach(([x, y]) => this.set(x, y, hex));
  }
  done() { this.g.putImageData(this.img, 0, 0); return this.c; }
}

// ---------- 小尺寸重复贴图 ----------
function makeTextures() {
  const T = {};
  let p = new Pix(16, 16); p.noise(0, 0, 16, 16, [P.stone0, P.stone, P.stone, P.stone1], 2, 0.5); p.specks(0, 0, 16, 16, P.paper, 0.05);
  for (let i = 0; i < 16; i++) p.set(i, 15, P.stone0); T.slab = texFrom(p.done());

  p = new Pix(32, 16); p.noise(0, 0, 32, 16, [P.stone0, P.stone, P.stone1], 5, 0.4);
  for (let y = 0; y < 16; y++) for (let x = 0; x < 32; x++) { const off = (Math.floor(y / 5) % 2) * 5; if (y % 5 === 4 || (x + off) % 10 === 9) p.set(x, y, P.ink1); }
  T.wall = texFrom(p.done());

  p = new Pix(24, 24); p.noise(0, 0, 24, 24, [P.paper0, P.paper, P.paper, P.paper1], 7, 0.6);
  for (let y = 0; y < 24; y++) { p.set(0, y, P.wood0); p.set(1, y, P.wood); p.set(12, y, P.wood0); p.set(13, y, P.wood); }
  for (let x = 0; x < 24; x++) { p.set(x, 0, P.wood0); p.set(x, 11, P.wood0); p.set(x, 12, P.wood); }
  T.side = texFrom(p.done());

  p = new Pix(16, 16); p.noise(0, 0, 16, 16, ['#e2dccf', '#ece7dd', '#f4f0e8'], 9, 0.5); T.white = texFrom(p.done());

  p = new Pix(16, 16);
  for (let x = 0; x < 16; x++) { const band = Math.floor(x / 4) % 2; for (let y = 0; y < 16; y++) p.set(x, y, band ? (y % 4 === 3 ? P.wood0 : P.wood) : (y % 4 === 3 ? P.wood0 : P.wood1)); }
  p.specks(0, 0, 16, 16, P.wood0, 0.06); T.wood = texFrom(p.done());

  p = new Pix(16, 16);
  for (let x = 0; x < 16; x++) for (let y = 0; y < 16; y++) { const col = x % 4; const c = col === 0 ? P.tile0 : col === 1 ? P.tile1 : P.tile; p.set(x, y, (y % 4 === 3 && col !== 0) ? P.tile0 : c); }
  T.tile = texFrom(p.done());

  p = new Pix(16, 16); p.noise(0, 0, 16, 16, [P.red0, P.red, P.red], 11, 0.5); T.redwall = texFrom(p.done());

  p = new Pix(16, 16); p.noise(0, 0, 16, 16, ['#4b3021', '#5c3a27', '#6e4630'], 13, 0.3);
  for (let y = 0; y < 16; y++) { p.set(3, y, '#3a2419'); p.set(10, (y + 5) % 16, '#3a2419'); } T.bark = texFrom(p.done());

  p = new Pix(16, 16); p.noise(0, 0, 16, 16, [P.soil0, P.soil, P.soil1], 17, 0.5);
  for (let x = 0; x < 16; x++) for (let y = 0; y < 16; y++) if (y % 4 === 0) p.set(x, y, P.soil0); T.soil = texFrom(p.done());

  // 树叶：灰阶图案，用顶点色染成绿色
  p = new Pix(32, 32);
  for (let y = 0; y < 32; y++) for (let x = 0; x < 32; x++) { const n = hash2(x >> 1, y >> 1) * 0.6 + hash2(x, y) * 0.4; p.set(x, y, n > 0.78 ? '#ffffff' : n > 0.45 ? '#d6d6d6' : n > 0.2 ? '#a8a8a8' : '#747474'); }
  T.leaf = texFrom(p.done());

  p = new Pix(48, 48); p.noise(0, 0, 48, 48, [P.sea0, P.blu0, P.sea, P.sea], 19, 0.18);
  for (let k = 0; k < 40; k++) { const x = Math.floor(hash2(k, 1) * 48), y = Math.floor(hash2(k, 2) * 48), L = 3 + Math.floor(hash2(k, 3) * 6); for (let i = 0; i < L; i++) p.set((x + i) % 48, y, k % 3 ? P.sea1 : P.blu1); }
  T.water = texFrom(p.done());

  p = new Pix(64, 64);
  for (let k = 0; k < 26; k++) { const x = Math.floor(hash2(k, 7) * 64), y = Math.floor(hash2(k, 8) * 64); p.set(x, y, '#ffffff'); p.set((x + 1) % 64, y, '#cfe6ff', 200); }
  T.sparkle = texFrom(p.done());

  p = new Pix(32, 32); p.noise(0, 0, 32, 32, ['#1d2a33', '#26363f', '#33444a', '#3f4f52'], 23, 0.45); T.bed = texFrom(p.done());

  const [bc, bg] = makeCanvas(32, 32); const grd = bg.createRadialGradient(16, 16, 2, 16, 16, 16);
  grd.addColorStop(0, 'rgba(20,12,30,0.55)'); grd.addColorStop(1, 'rgba(20,12,30,0)'); bg.fillStyle = grd; bg.fillRect(0, 0, 32, 32);
  T.blob = texFrom(bc, { repeat: false }); T.blob.magFilter = THREE.LinearFilter;

  const [gc, gg] = makeCanvas(32, 32); const g2 = gg.createRadialGradient(16, 16, 0, 16, 16, 16);
  g2.addColorStop(0, 'rgba(255,255,255,1)'); g2.addColorStop(0.35, 'rgba(255,255,255,0.5)'); g2.addColorStop(1, 'rgba(255,255,255,0)'); gg.fillStyle = g2; gg.fillRect(0, 0, 32, 32);
  T.glow = texFrom(gc, { repeat: false }); T.glow.magFilter = THREE.LinearFilter;
  return T;
}

function awningTex(a, b) {
  const p = new Pix(16, 16);
  for (let x = 0; x < 16; x++) for (let y = 0; y < 16; y++) p.set(x, y, (Math.floor(x / 4) % 2 ? a : b));
  for (let x = 0; x < 16; x++) p.set(x, 15, P.ink1);
  return texFrom(p.done());
}

// ---------- 招牌：牌匾字用站酷小薇，二值化成硬边像素字 ----------
function signTexture(text, { bg = P.wood0, fg = P.gold1, border = P.gold, px = 22 } = {}) {
  const font = `${px}px "ZCOOL XiaoWei","Songti SC","STSong",serif`;
  const [, mg] = makeCanvas(4, 4); mg.font = font;
  const tw = Math.ceil(mg.measureText(text).width), W = tw + 18, H = px + 12;
  const [c, g] = makeCanvas(W, H);
  g.fillStyle = border; g.fillRect(0, 0, W, H); g.fillStyle = bg; g.fillRect(2, 2, W - 4, H - 4);
  const [tc, tg] = makeCanvas(W, H); tg.font = font; tg.textAlign = 'center'; tg.textBaseline = 'middle'; tg.fillStyle = fg; tg.fillText(text, W / 2, H / 2 + 1);
  const id = tg.getImageData(0, 0, W, H); for (let i = 3; i < id.data.length; i += 4) id.data[i] = id.data[i] > 105 ? 255 : 0; tg.putImageData(id, 0, 0);
  g.drawImage(tc, 0, 0);
  return { tex: texFrom(c, { repeat: false }), w: W, h: H };
}

// ---------- 地面：整张画，北岸南岸各一张 ----------
const GPPU = 7; // 每个单位 7 个像素
function paintGround(areas, s0, s1) {
  const W = Math.round((T1 - T0) * GPPU), H = Math.round((s1 - s0) * GPPU);
  const [c, g] = makeCanvas(W, H); const img = g.createImageData(W, H), d = img.data;
  const GR = [rgb(P.grass0), rgb(P.grass), rgb(P.grass1)], ST = [rgb(P.stone0), rgb(P.stone), rgb(P.stone1), rgb('#a39b92')];
  const DI = [rgb(P.dirt0), rgb(P.dirt), rgb(P.dirt1)], FL = [rgb(P.pink), rgb(P.gold1), rgb(P.paper1)], GROUT = rgb('#5d5660');
  for (let j = 0; j < H; j++) for (let i = 0; i < W; i++) {
    const gx = i, gy = Math.round((S1 - s1) * GPPU) + j; // 全局像素坐标，南北两张图案对齐
    const t = T0 + (i + 0.5) / GPPU, s = s1 - (j + 0.5) / GPPU;
    let kind = 'grass', edge = -1;
    for (const a of areas) if (t >= a.t0 && t <= a.t1 && s >= a.s0 && s <= a.s1) { kind = a.k; edge = Math.max(edge, Math.min(t - a.t0, a.t1 - t, s - a.s0, a.s1 - s)); }
    if (Math.abs(s) >= RIVER && Math.abs(s) < RIVER + 0.32) kind = 'curb';
    const h = hash2(gx, gy), n = fbm(gx * 0.09, gy * 0.09);
    if (kind !== 'grass' && kind !== 'curb' && edge >= 0 && edge < 0.45 && h < 0.5 - edge) kind = 'grass';
    let col;
    if (kind === 'stone' || kind === 'court') {
      const row = Math.floor(gy / 4), bx = Math.floor((gx + (row % 2) * 4) / 8);
      const gr = (gy % 4 === 0) || ((gx + (row % 2) * 4) % 8 === 0);
      const pick = hash2(bx, row); col = gr ? GROUT : ST[Math.max(0, Math.min(3, Math.floor(pick * 3.2 + (h - 0.5) * 0.6)))];
      if (kind === 'court' && !gr && pick > 0.8) col = rgb(P.red1);
    } else if (kind === 'dirt' || kind === 'yard') {
      col = DI[Math.max(0, Math.min(2, Math.floor(n * 3.2 + (h - 0.5) * 0.7)))];
      if (h > 0.985) col = ST[2];
      if (kind === 'yard' && fbm(gx * 0.2, gy * 0.2) > 0.62) col = GR[1];
    } else if (kind === 'curb') {
      col = (Math.abs(s) < RIVER + 0.12) ? ST[0] : ST[2];
    } else {
      const v = n * 2.6 + (h - 0.5) * 0.9; col = GR[Math.max(0, Math.min(2, Math.floor(v)))];
      if (h > 0.9965) col = FL[Math.floor(hash2(gx + 5, gy) * 3)];
    }
    const k = (j * W + i) * 4; d[k] = col[0]; d[k + 1] = col[1]; d[k + 2] = col[2]; d[k + 3] = 255;
  }
  g.putImageData(img, 0, 0);
  const tex = texFrom(c, { repeat: false }); tex.wrapS = tex.wrapT = THREE.ClampToEdgeWrapping;
  return tex;
}
