import * as THREE from 'three';
import { EffectComposer } from 'three/addons/postprocessing/EffectComposer.js';
import { RenderPass } from 'three/addons/postprocessing/RenderPass.js';
import { UnrealBloomPass } from 'three/addons/postprocessing/UnrealBloomPass.js';
import { ShaderPass } from 'three/addons/postprocessing/ShaderPass.js';
import { OutputPass } from 'three/addons/postprocessing/OutputPass.js';
import { HorizontalTiltShiftShader } from 'three/addons/shaders/HorizontalTiltShiftShader.js';
import { VerticalTiltShiftShader } from 'three/addons/shaders/VerticalTiltShiftShader.js';
import { mergeGeometries } from 'three/addons/utils/BufferGeometryUtils.js';

// =====================================================================
// 苏七镇 HD-2D 样机
// 坐标：镇子沿峨眉河排布。t 轴顺流（东偏南 18°），s 轴指向北岸。
// 所有静物在“河框架”里建：x = t，z = -s，再整体绕 Y 转 -18° 放进世界。
// 相机永远朝正北看，所以精灵只要朝 +z 就对着镜头。
// =====================================================================

const TH = 18 * Math.PI / 180;
const DX = Math.cos(TH), DZ = Math.sin(TH);      // t 轴在世界里的方向
const NX = Math.sin(TH), NZ = -Math.cos(TH);     // s 轴在世界里的方向
const toWorld = (t, s) => ({ x: t * DX + s * NX, z: t * DZ + s * NZ });
const toFrame = (x, z) => ({ t: x * DX + z * DZ, s: x * NX + z * NZ });

// 地图范围（河框架）
const T0 = -80, T1 = 64, S0 = -64, S1 = 124;
const RIVER = 15;            // 河宽一半
const DECK = 1.1;            // 桥面宽一半
const SPANS = 17;            // 17 孔
const SPAN_L = (RIVER * 2) / SPANS;
const WATER_Y = -0.85, FLOOD_Y = 0.035, BED_Y = -2.2, DECK_TOP = 0.02;

// 调色板：美术生图包 1.2，外加少量土木色
const P = {
  red0:'#8C2F27', red:'#C0392B', red1:'#E8746A', gold0:'#8A6410', gold:'#D4AF37', gold1:'#F4D97A',
  pur0:'#3E3160', pur:'#5B4B8A', pur1:'#9584C4', paper0:'#B8A88E', paper:'#E8DDD0', paper1:'#FFF8EE',
  ink0:'#1E1A2A', ink:'#2C2438', ink1:'#5A4E68', bam0:'#2F5940', bam:'#4A7C59', bam1:'#7BAE84',
  sea0:'#1F3A5C', sea:'#3A6491', sea1:'#6F9BC4', blu0:'#2E4A7A', blu:'#4A6FA5', blu1:'#7E9FCB',
  tile0:'#34323d', tile:'#4a4855', tile1:'#686676', wood0:'#46291d', wood:'#6b432d', wood1:'#916140',
  stone0:'#6d6670', stone:'#8f8893', stone1:'#b1aab4', soil0:'#553826', soil:'#744e35', soil1:'#946845',
  grass0:'#3b6a3d', grass:'#57894a', grass1:'#84ab5c', dirt0:'#93785a', dirt:'#b09470', dirt1:'#cbb08a',
  pink:'#e99ab0', leaf0:'#335e34', leaf:'#548546', leaf1:'#8db35a',
};

// 可复现的随机
function mulberry32(a) { return function () { a |= 0; a = a + 0x6D2B79F5 | 0; let t = Math.imul(a ^ a >>> 15, 1 | a); t = t + Math.imul(t ^ t >>> 7, 61 | t) ^ t; return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }
const rnd = mulberry32(20260615);
const rr = (a, b) => a + (b - a) * rnd();
function hash2(x, y) { let h = (Math.imul(x | 0, 374761393) + Math.imul(y | 0, 668265263)) | 0; h = Math.imul(h ^ (h >>> 13), 1274126177); h ^= h >>> 16; return (h >>> 0) / 4294967296; }
function vnoise(x, y) {
  const xi = Math.floor(x), yi = Math.floor(y), xf = x - xi, yf = y - yi;
  const a = hash2(xi, yi), b = hash2(xi + 1, yi), c = hash2(xi, yi + 1), d = hash2(xi + 1, yi + 1);
  const u = xf * xf * (3 - 2 * xf), v = yf * yf * (3 - 2 * yf);
  return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
}
const fbm = (x, y) => vnoise(x, y) * 0.55 + vnoise(x * 2.3, y * 2.3) * 0.3 + vnoise(x * 5.1, y * 5.1) * 0.15;
const hexRGB = (h) => [parseInt(h.slice(1, 3), 16), parseInt(h.slice(3, 5), 16), parseInt(h.slice(5, 7), 16)];

// 时间规则：与 server-claude/src/time.js 一致（北京时间）
const TZ = 8 * 3600 * 1000;
function bj(now = Date.now()) { const d = new Date(now + TZ); return { mo: d.getUTCMonth() + 1, day: d.getUTCDate(), wd: d.getUTCDay(), h: d.getUTCHours() + d.getUTCMinutes() / 60 }; }
const isMarketDay = (now) => bj(now).day % 2 === 1;            // 逢单日赶场
const isFloodSeason = (now) => { const m = bj(now).mo; return m >= 6 && m <= 8; };
const isNightTour = (h) => h >= 19.5 && h < 20.5;              // 夜游 19:30～20:30

// 全局状态
const S = {
  hour: bj().h, follow: true, market: isMarketDay(), flood: isFloodSeason(), lamps: 5,
  quality: /Mobi|Android|iPhone|iPad/i.test(navigator.userAgent) ? 'mid' : 'high',
  zoom: 30, reduced: matchMedia('(prefers-reduced-motion: reduce)').matches,
};

// 对白：全部摘自《苏七镇 · 阶段 1 设计 v1.0》第 4 节和《文案改写版 v2》A8-3
const LINES = {
  arrive: '到啦～ 罗曼山庄 席还没散', leave: '吃好了？走 带你回镇上',
  marketOn: '今天走赶场', marketOff: '双日不赶场 明天来', tourist: '游客买贵些',
  gov: '这是镇政府 里面没啥好玩的', school: '我在这儿念的小学 那棵树那时候就在了',
  leaf: '你在这儿', box: '点灯 一盏 30 棵', lampOne: '亮了一盏', lampAll: '桥全亮了',
  bridge: '桥没栏杆 走中间哈', bridgeFlood: '涨水了 踩着走', southBank: '你家在这边',
  home: '这间是你的 安逸不', luoluoDoor: '落落巴倒你门口睡了一觉', temple: '月老在这儿 想给谁牵线',
  qiuqiuFound: '求求躲在这儿', kicked: '这个球今天踢过了',
  xiduo: '喜多 柯基 看家的', luoluo: '长毛的那只叫落落。落落 天天 合起来是落雨天',
  tiantian: '短毛的那只叫天天。落雨天 loyalty', qiuqiu: '求求 美短 不是求你的意思哈',
};
