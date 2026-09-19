'use strict';
const C = require('./config');

/**
 * 画布图远程加载（HANDOFF §0.9）：云函数 canvasFile 的判定。
 * 为什么走云函数：云存储权限是「仅创建者可读写」，阿鱼在控制台传的图玩家读不到（wx.cloud.downloadFile 回
 * empty download url，9/19 第 30 版真机）；改权限要付费版。云函数有管理员权限，读得到，一块一块回给小程序。
 * 跟其它规则文件一样：同步纯函数，不做 I/O。
 */

/**
 * 这个 File ID 能不能读：只许 cloud://环境.桶/canvas/ 下面的文件（画布的底图、积木图），
 * 别的文件（以后可能放别的东西）一律不给；路径里不能有「..」、不能有空白
 */
function canReadCanvas(fileID) {
  if (typeof fileID !== 'string' || !fileID.startsWith('cloud://')) return false;
  if (/\s/.test(fileID) || fileID.includes('..')) return false;
  const rest = fileID.slice('cloud://'.length);
  const slash = rest.indexOf('/');
  if (slash <= 0) return false;
  return rest.slice(slash + 1).startsWith('canvas/');
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
