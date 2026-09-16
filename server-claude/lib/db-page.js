'use strict';
/**
 * 分页读全一个云开发数据库查询。
 *
 * 背景：微信云开发数据库在云函数端 collection.get() 不写 limit 时，一次最多只返回 100 条
 * （官方 Collection.get / Collection.limit 文档写明的上限，社区也有很多踩坑记录）。
 * 宴会厅人数会超过 100（12 桌 120 座 + 长凳不限人数），下面这几处原来的写法都会静默漏读：
 * 分座时算不全某桌已有几人、椅子号可能重复分配；桌上少画人；进厅提示的敬酒/簿子计数不对。
 *
 * 这个文件要做 I/O（依赖调用方传入的云开发查询对象），不是同步纯函数，所以不放进 src/
 * （README 的约定：src/ 只放纯函数）。跟 src/ 的规则文件一样，云函数打包不能 require
 * 文件夹外的代码，部署前用 scripts/sync-cf-rules.js 同步进各云函数自己的 lib/ 文件夹。
 *
 * 用法（enterHall/index.js 的例子）：
 *   const { fetchAllPages } = require('./lib/db-page');
 *   const seats = await fetchAllPages(
 *     () => db.collection('seat').where({ table_id: _.neq(BENCH) }),
 *     { orderBy: [['_id', 'asc']], maxTotal: C.BANQUET_PAGE_MAX_TOTAL },
 *   );
 */

// 云开发单次 get() 的官方上限，写死在这里，调用方不应该传更大的 pageSize
const MAX_PAGE_SIZE = 100;

/**
 * @param queryFactory () => Query
 *   每次调用都从头返回同一个「基础查询」（已经 .where() 好，还没 .orderBy/.skip/.limit）。
 *   用工厂函数而不是直接传一个 Query 对象，是为了每一页都从干净的查询重新构建
 *   .orderBy().skip().limit()，不依赖 SDK 内部 Query 对象是否真的不可变、链式调用有没有副作用。
 * @param opts {{
 *   orderBy?: Array<[string, 'asc'|'desc']>,  排序字段，默认 [['_id','asc']]；
 *                                              数组给多个按顺序多级排序，用来在主排序字段
 *                                              （比如 created_at）有相同值时保持分页稳定。
 *   pageSize?: number,   每页几条，默认、上限都是 100（云开发的硬上限，传更大也会被夹到 100）
 *   maxTotal: number,    总上限，必传——分页读全没有这个会失控（表被写爆时无限翻页）。
 *                        业务代码从 src/config.js 取这个数字，不要在调用点写死。
 * }}
 * @returns {Promise<Array>} 按 orderBy 顺序排好、最多 maxTotal 条的完整结果
 */
async function fetchAllPages(queryFactory, opts) {
  if (typeof queryFactory !== 'function') {
    throw new Error('fetchAllPages: queryFactory 必须是函数，每次返回一个新查询');
  }
  const maxTotal = opts && opts.maxTotal;
  if (!(maxTotal > 0)) {
    throw new Error('fetchAllPages: maxTotal 必须是一个正数（防止分页失控），业务代码从 config.js 取');
  }
  const orderBy = (opts && opts.orderBy) || [['_id', 'asc']];
  const pageSize = Math.min((opts && opts.pageSize) || MAX_PAGE_SIZE, MAX_PAGE_SIZE);

  const all = [];
  let skip = 0;
  for (;;) {
    const remaining = maxTotal - all.length;
    if (remaining <= 0) break; // 撞到总上限，防失控，不再往下翻
    const take = Math.min(pageSize, remaining);

    let q = queryFactory();
    for (const [field, dir] of orderBy) q = q.orderBy(field, dir);
    const { data } = await q.skip(skip).limit(take).get();

    all.push(...data);
    if (data.length < take) break; // 这页不满，说明已经读到底了
    skip += data.length;
  }
  return all;
}

module.exports = { fetchAllPages, MAX_PAGE_SIZE };
