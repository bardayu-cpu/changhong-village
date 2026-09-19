// 云函数 canvasFile：把云存储里的画布图一块一块回给小程序（HANDOFF §0.9 远程加载，01 9/19 派）。
// 为什么走云函数：云存储权限是「仅创建者可读写」，阿鱼在控制台传的图玩家读不到，wx.cloud.downloadFile 回
// empty download url（第 30 版真机）；改权限要付费版。控制台说云函数和服务端始终有全部文件的读写权限，所以这里读得到。
// 判定在 rules/canvas.js（只许读 canvas/ 下面的，一块多大），部署前用 node scripts/sync-cf-rules.js 同步。
// 客户端（wxgame/remote.js 的 @fetchChunks）：wx.cloud.callFunction({ name: 'canvasFile', data: { fileID, offset } })，
// 从 0 开始一块一块要，直到 done。回 { ok, total, offset, size, data（这一块，base64）, done }。
// 同一个热实例里，整个文件在内存里留 CACHE_MS：一张图要好几块，不用每块都从存储下一遍整张。
const cloud = require('wx-server-sdk');
const canvas = require('./rules/canvas');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });

const CACHE_MS = 5 * 60 * 1000;
let cache = null;   // { fileID, buf, at }

exports.main = async (event) => {
  const { fileID } = event || {};
  const offset = event && event.offset !== undefined ? event.offset : 0;
  if (!canvas.canReadCanvas(fileID)) return { ok: false, reason: 'bad_request' };
  try {
    const now = Date.now();
    if (!cache || cache.fileID !== fileID || now - cache.at > CACHE_MS) {
      const res = await cloud.downloadFile({ fileID });
      cache = { fileID, buf: res.fileContent, at: now };
    }
    const buf = cache.buf;
    const r = canvas.chunkRange(buf.length, offset);
    if (!r.ok) return r;
    const part = buf.subarray(r.start, r.end);
    return { ok: true, total: buf.length, offset: r.start, size: part.length, data: part.toString('base64'), done: r.done };
  } catch (e) {
    // 文件不在、存储出错：原因打一行进云函数日志，也带回去（客户端调试版日志面板能看到）
    const why = String((e && (e.errMsg || e.message)) || e).slice(0, 200);
    console.error('canvasFile 读文件出错：', why);
    cache = null;
    return { ok: false, reason: 'download_failed', detail: why };
  }
};
