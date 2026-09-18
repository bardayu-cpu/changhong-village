// 云函数 hallPulse：宴会厅里的「心跳」。
//
// 干什么：人在宴会厅里的时候，实时知道「有没有人刚敬了我一杯」——不用等下一次进厅，
// 才从 enterHall 的进厅提示（digest）里看到「老王敬了你一杯」，而是当场（几秒内）弹出来、
// 人站起来（阿鱼 9/18 晚提的需求，见回执「宴会厅服务端加固」系列）。
//
// 谁调、多久调一次：客户端只在人已经在宴会厅界面里时才调用，每 8 秒调一次；离开宴会厅
// 就不再调。跟 enterHall 不是一回事——enterHall 是「走进来那一下」，hallPulse 是「人还待着
// 的时候一直轻轻问一句有没有新情况」。
//
// since 的约定（毫秒时间戳，数字）：
//   - 客户端把上一次调用拿到的 now 原样传回来，当这一次的 since；
//   - 第一次进厅、手上还没有「上一次 now」时，不传 since（或者传一个不是正数的值）。
//
// 为什么 since 缺、不是正数时只回空、连 toast 表都不查：
//   这种情况一定是刚进厅、第一次调 hallPulse——进厅之前收到的敬酒，enterHall 的进厅提示
//   已经报过一遍了。如果这里照样去查表，会把 enterHall 已经报过的同一批敬酒在厅里又弹一次，
//   人重复站起来。所以第一次直接跳过查询，只用这一次的 now 帮客户端把「上一次 now」这个
//   基准建立起来，从下一次心跳开始才真的去查有没有新敬酒。
//
// 性能（这个函数会被高频调，人在厅里时每人每 8 秒一次）：
//   - 最多查一张表（toast），且只在确实可能有新敬酒（since 是合法正数）时才查；
//   - toasts 为空时（不管是因为 since 不合法，还是查出来确实没有新的）一次都不查 resident 表；
//   - toast 表本身只取最多 MAX_TOASTS_PER_PULSE 条，一次 8 秒的间隔正常攒不了这么多，
//     所以不用像 enterHall/readBook 那样分页读全（lib/db-page.js 用不上）；
//     真的一次被敬超过这个数（比如同时被很多人敬酒），多出来的那些这次拿不到，
//     而且这次返回的 now 会把「游标」往前推过去，这些没拿到的旧敬酒后面也不会再补——
//     这是有意的取舍，hallPulse 只是「当场提个醒」，不是敬酒记录的唯一来源，
//     toast 表本身、以及下次进厅时 enterHall 的统计都不受影响。这个取舍是否可接受，
//     连同 toast 表要不要加索引，写进了回报给主程的风险清单，请阿鱼/主程确认。
const cloud = require('wx-server-sdk');

cloud.init({ env: cloud.DYNAMIC_CURRENT_ENV });
const db = cloud.database();
const _ = db.command;

const MAX_TOASTS_PER_PULSE = 10;
// 往回多看 3 秒（主程 9/19 加）：敬酒云函数先取 Date.now() 再写库，写库那几十毫秒里正好赶上一次心跳，
// 这条的 created_at 会比这次心跳的 now 早、却没被查到，下次 since 又推过去了，就永远漏报。
// 多看的这 3 秒里可能有上一次报过的，客户端按「from:created_at」去重（main.gd 的 pulse_seen）
const OVERLAP_MS = 3000;

exports.main = async (event) => {
  const { since } = event || {};
  const { OPENID } = cloud.getWXContext();
  const now = Date.now();

  // since 缺、不是数字、不是正数：见文件头注释，直接回空，不查任何表
  const sinceValid = typeof since === 'number' && isFinite(since) && since > 0;
  if (!sinceValid) return { ok: true, now, toasts: [], names: {} };

  try {
    // 只按 since 做下限查询（created_at 严格大于 since），按时间升序、最多取 10 条。
    // 规格要求的是「since < created_at <= now」，上限 <= now 没有写进 where 条件里，
    // 而是查完之后在内存里过滤（下面 rows.filter）——两种写法结果完全一样：这里已经按
    // created_at 升序排列，created_at > now 的行（只有极小概率跟另一次 toast 调用撞在
    // 同一瞬间才可能出现）必然排在所有 <= now 的行之后，不会把 <= now 的行从前 10 名里
    // 挤出去，所以先 limit(10) 再过滤、和先过滤再 limit(10) 拿到的是同一批数据。
    // 这样写是为了不用在假 db 测试工具（test/cf-mock.test.js）里额外实现
    // db.command 的 gt(...).and(lte(...)) 链式调用。
    // 保留 <= now 这一步过滤，是为了保护「下一次心跳」不漏报：如果这次把一条
    // created_at 恰好等于/晚于 now 的记录当成「已读」报了出去，而 now 本身还没来得及
    // 覆盖到它，下次心跳拿这次的 now 当 since 时，会因为 created_at 不大于 since 而
    // 再也查不到这条——等于漏报。所以宁可这次不报，下次心跳（since 还没推过去）自然能补上。
    const { data: rows } = await db.collection('toast')
      .where({ to: OPENID, created_at: _.gt(since - OVERLAP_MS) })
      .orderBy('created_at', 'asc')
      .limit(MAX_TOASTS_PER_PULSE)
      .get();

    const toasts = rows
      .filter(r => r.created_at <= now)
      .map(r => ({ from: r.from, created_at: r.created_at }));

    if (!toasts.length) return { ok: true, now, toasts: [], names: {} };

    // 敬酒人的昵称、形象：resident 表 _id 就是 openid，写法照 enterHall。
    // toasts 最多 10 条，from 去重后最多 10 个，远低于 _.in 一次最多传 100 个 id 的上限，
    // 不需要分页/分批查（跟 enterHall 按 100 一批查名字是同一条上限，这里天然够用）。
    const fromIds = Array.from(new Set(toasts.map(t => t.from)));
    const names = {};
    // 查不到 resident 记录的 from 也要出现在 names 里，先兜底填上，查到了再覆盖
    for (const id of fromIds) names[id] = { nick: '', avatar: -1 };
    const { data: residents } = await db.collection('resident')
      .where({ _id: _.in(fromIds) })
      .field({ _id: true, nick: true, avatar: true })
      .get();
    for (const r of residents) {
      names[r._id] = { nick: r.nick || '', avatar: r.avatar === undefined ? -1 : r.avatar };
    }

    // 记下「当场报过的敬酒报到哪了」：下次进厅 enterHall 的进厅提示从这之后算，
    // 不然在厅里当场看过的敬酒，下次进厅又弹一遍（主程 9/19 加）。没有 seat（没进过厅）就算了
    const seenAt = Math.max(...toasts.map(t => t.created_at));
    await db.collection('seat').doc(OPENID).update({ data: { toast_seen_at: seenAt } }).catch(() => null);

    return { ok: true, now, toasts, names };
  } catch (e) {
    // 数据库异常不抛给客户端——这个函数每 8 秒被调一次，一次瞬时抖动不该让客户端报错炸掉。
    return { ok: false, reason: 'network' };
  }
};
