'use strict';
const C = require('./config');

/**
 * 画布图远程加载（HANDOFF §0.9）：云函数 canvasFile 的判定。
 * 为什么走云函数：云存储权限是「仅创建者可读写」，阿鱼在控制台传的图玩家读不到（wx.cloud.downloadFile 回
 * empty download url，9/19 第 30 版真机）；改权限要付费版。云函数有管理员权限，读得到，一块一块回给小程序。
 * 跟其它规则文件一样：同步纯函数，不做 I/O。
 */

// 白名单（01 9/20 定，起因：03 查出 %2e%2e 这种编码绕过了只查字面「..」的写法，报告见回执）：
// 只放行长成 cloud://<env>.<bucket>/canvas/<路径> 的，其余一律拒。别再往「..」上打补丁——再想出一种编码又得补一次。
const HOST_RE = /^[A-Za-z0-9-]+(\.[A-Za-z0-9-]+)+$/;   // env.bucket：字母数字连字符，点分隔
const SEG_RE = /^[A-Za-z0-9_.-]+$/;                    // 路径的每一段：字母数字下划线点连字符
const MAX_LEN = 512;                                   // File ID 再长也没意义，长的一律拒

/**
 * 这个 File ID 能不能读：只许 cloud://环境.桶/canvas/ 下面的文件（画布的底图、积木图），别的一律不给。
 * 路径里只认字母、数字、下划线、点、连字符、斜杠；不能连着两个点、不能空段（//）、不能单独一个点、不能以 / 开头。
 * 百分号编码（%2e%2e、%00）、反斜杠、全角点、问号井号、空白、控制字符、中文都不在白名单里，直接拒
 */
function canReadCanvas(fileID) {
  if (typeof fileID !== 'string') return false;
  if (fileID.length === 0 || fileID.length > MAX_LEN) return false;
  const PREFIX = 'cloud://';
  if (!fileID.startsWith(PREFIX)) return false;
  const rest = fileID.slice(PREFIX.length);
  const slash = rest.indexOf('/');
  if (slash <= 0) return false;
  if (!HOST_RE.test(rest.slice(0, slash))) return false;
  const path = rest.slice(slash + 1);
  if (!path.startsWith('canvas/')) return false;
  if (path.includes('..')) return false;
  const segs = path.split('/');
  if (segs.length < 2) return false;            // canvas/ 后面得真有东西
  for (const seg of segs) {
    if (seg === '' || seg === '.') return false;
    if (!SEG_RE.test(seg)) return false;
  }
  return true;
}

/**
 * 从第 offset 字节起这一块：{ok:true, start, end, done}；offset 不是整数、是负数、超过文件大小回 bad_request
 * @param total 文件一共多少字节
 * @param chunk 一块多大，默认 config.CANVAS_CHUNK
 */
function chunkRange(total, offset, chunk = C.CANVAS_CHUNK) {
  if (!Number.isInteger(offset) || offset < 0 || offset > total) return { ok: false, reason: 'bad_request' };
  const end = Math.min(offset + chunk, total);
  return { ok: true, start: offset, end, done: end >= total };
}

module.exports = { canReadCanvas, chunkRange };
