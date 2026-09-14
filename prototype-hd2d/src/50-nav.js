// =====================================================================
// 走路：点地面自动寻路（0.5 格网格上跑 A*，再拉直）。桥是唯一过河的路
// =====================================================================
const CELL = 0.5, GW = Math.round((T1 - T0) / CELL), GH = Math.round((S1 - S0) / CELL), PR = 0.32;
let GRID = null;
function walkable(t, s, r = PR) {
  if (t < T0 + 1.5 || t > T1 - 1.5 || s < S0 + 1.5 || s > S1 - 1.5) return false;
  if (Math.abs(s) < RIVER + 0.1 && Math.abs(t) > DECK - r) return false;
  for (const c of COLL) if (t > c.t0 - r && t < c.t1 + r && s > c.s0 - r && s < c.s1 + r) return false;
  return true;
}
const groundY = (t, s) => (Math.abs(s) < RIVER + 0.95 && Math.abs(t) < DECK) ? DECK_TOP : 0;
function buildGrid() {
  GRID = new Uint8Array(GW * GH);
  for (let j = 0; j < GH; j++) for (let i = 0; i < GW; i++) {
    const t = T0 + (i + 0.5) * CELL, s = S0 + (j + 0.5) * CELL;
    let ok = !(t < T0 + 1.5 || t > T1 - 1.5 || s < S0 + 1.5 || s > S1 - 1.5);
    if (ok && Math.abs(s) < RIVER + 0.1 && Math.abs(t) > DECK - PR) ok = false;
    GRID[j * GW + i] = ok ? 1 : 0;
  }
  for (const c of COLL) {
    const i0 = Math.max(0, Math.floor((c.t0 - PR - T0) / CELL)), i1 = Math.min(GW - 1, Math.floor((c.t1 + PR - T0) / CELL));
    const j0 = Math.max(0, Math.floor((c.s0 - PR - S0) / CELL)), j1 = Math.min(GH - 1, Math.floor((c.s1 + PR - S0) / CELL));
    for (let j = j0; j <= j1; j++) for (let i = i0; i <= i1; i++) {
      const t = T0 + (i + 0.5) * CELL, s = S0 + (j + 0.5) * CELL;
      if (t > c.t0 - PR && t < c.t1 + PR && s > c.s0 - PR && s < c.s1 + PR) GRID[j * GW + i] = 0;
    }
  }
}
const cellOK = (i, j) => i >= 0 && j >= 0 && i < GW && j < GH && GRID[j * GW + i] === 1;
const cellT = (i) => T0 + (i + 0.5) * CELL, cellS = (j) => S0 + (j + 0.5) * CELL;
function nearestOK(i, j, maxR = 40) {
  if (cellOK(i, j)) return [i, j];
  for (let r = 1; r <= maxR; r++) { let best = null, bd = 1e9;
    for (let dj = -r; dj <= r; dj++) for (let di = -r; di <= r; di++) { if (Math.max(Math.abs(di), Math.abs(dj)) !== r) continue; if (cellOK(i + di, j + dj)) { const d = di * di + dj * dj; if (d < bd) { bd = d; best = [i + di, j + dj]; } } }
    if (best) return best; }
  return null;
}
function losClear(a, b) {
  const d = Math.hypot(b.t - a.t, b.s - a.s), n = Math.ceil(d / 0.2);
  for (let k = 1; k < n; k++) { const t = a.t + (b.t - a.t) * k / n, s = a.s + (b.s - a.s) * k / n; if (!cellOK(Math.floor((t - T0) / CELL), Math.floor((s - S0) / CELL))) return false; }
  return true;
}
function findPath(from, to) {
  const st = nearestOK(Math.floor((from.t - T0) / CELL), Math.floor((from.s - S0) / CELL), 6);
  const gl = nearestOK(Math.floor((to.t - T0) / CELL), Math.floor((to.s - S0) / CELL));
  if (!st || !gl) return null;
  const N = GW * GH, start = st[1] * GW + st[0], goal = gl[1] * GW + gl[0];
  const g = new Float32Array(N).fill(Infinity), came = new Int32Array(N).fill(-1), closed = new Uint8Array(N);
  const heap = [], fv = [];
  const push = (n, f) => { heap.push(n); fv.push(f); let i = heap.length - 1; while (i > 0) { const p = (i - 1) >> 1; if (fv[p] <= fv[i]) break; [heap[p], heap[i]] = [heap[i], heap[p]]; [fv[p], fv[i]] = [fv[i], fv[p]]; i = p; } };
  const pop = () => { const top = heap[0], lh = heap.pop(), lf = fv.pop(); if (heap.length) { heap[0] = lh; fv[0] = lf; let i = 0; for (;;) { const l = 2 * i + 1, r = l + 1; let m = i; if (l < heap.length && fv[l] < fv[m]) m = l; if (r < heap.length && fv[r] < fv[m]) m = r; if (m === i) break; [heap[m], heap[i]] = [heap[i], heap[m]]; [fv[m], fv[i]] = [fv[i], fv[m]]; i = m; } } return top; };
  const hx = (n) => { const dx = Math.abs(n % GW - gl[0]), dy = Math.abs(((n / GW) | 0) - gl[1]); return (dx + dy) + (Math.SQRT2 - 2) * Math.min(dx, dy); };
  g[start] = 0; push(start, hx(start));
  const DIRS = [[1, 0, 1], [-1, 0, 1], [0, 1, 1], [0, -1, 1], [1, 1, Math.SQRT2], [1, -1, Math.SQRT2], [-1, 1, Math.SQRT2], [-1, -1, Math.SQRT2]];
  let found = false, guard = 0;
  while (heap.length && guard++ < 400000) {
    const n = pop(); if (closed[n]) continue; if (n === goal) { found = true; break; } closed[n] = 1;
    const i = n % GW, j = (n / GW) | 0;
    for (const [di, dj, c] of DIRS) {
      const ni = i + di, nj = j + dj; if (!cellOK(ni, nj)) continue;
      if (di && dj && (!cellOK(i + di, j) || !cellOK(i, j + dj))) continue;
      const m = nj * GW + ni, ng = g[n] + c; if (ng < g[m]) { g[m] = ng; came[m] = n; push(m, ng + hx(m)); }
    }
  }
  if (!found) return null;
  const cells = []; for (let n = goal; n !== -1; n = came[n]) cells.push({ t: cellT(n % GW), s: cellS((n / GW) | 0) });
  cells.reverse();
  const exact = walkable(to.t, to.s) ? { t: to.t, s: to.s } : cells[cells.length - 1];
  cells[cells.length - 1] = exact;
  const out = []; let a = { t: from.t, s: from.s }, k = 0;
  while (k < cells.length) { let far = k; for (let m = cells.length - 1; m > k; m--) if (losClear(a, cells[m])) { far = m; break; } out.push(cells[far]); a = cells[far]; k = far + 1; }
  return out;
}
