# server-claude · 苏七镇奇缘服务端规则

> 作者：Claude。**Codex 请只读、只调用，不要修改本目录。**
> 有意见写进根目录 `IDEAS.md`。
> 对应文档：`docs/苏七镇-阶段1设计-v1.0.md`；踢球规则见 GDD v1.2 的 4.6

## 这是什么

阶段 1 的全部游戏规则，写成**纯函数**：不依赖引擎、不依赖数据库、不依赖微信 SDK。
输入状态，输出判定。云函数拿它做校验，客户端也可以拿它做即时预览。

## 目录

```
src/config.js    全部可调参数。改平衡改这里，不要动 rules
src/time.js      北京时间、赶场日、涨水季、早市、夜游、周起点
src/farm.js      作物生长/成熟/烂、收获、偷菜产出、两个集市的价格
src/steal.js     偷菜配额、喜多看家
src/tree.js      邀请树、三层关系、扩列、可能认识的人
src/temple.js    月老庙：外殿牵红线、内殿许愿求签、找介绍人
src/town.js      桥灯、踢球、镇报
test/rules.test.js  92 条测试，零依赖
cloudfunctions/login/  云函数：返回调用者的 openid，已部署到 cloud1-d9ggg36tj34742bef
```

## 云函数

部署（在任意目录执行，需要微信开发者工具已登录）：

```bash
/Applications/wechatwebdevtools.app/Contents/MacOS/cli cloud functions deploy --env cloud1-d9ggg36tj34742bef --paths "<本目录的完整路径>/cloudfunctions/login" --appid wx26cb1101e51f4a47 --remote-npm-install
```

第一次创建时如果报「当前函数处于 Creating 状态」，等二三十秒再执行一次。

## 跑测试

```bash
node test/rules.test.js
```

## 给 Codex 的接口约定

全部函数是同步纯函数，签名见各文件头部注释。三条约定：

1. **随机数由调用方生成**并作为参数传入（`guardRoll`、`rand`）。这样服务端可复现、测试可断言。
2. **时间由调用方传入** `now`，不在模块里调 `Date.now()`。
3. **不做 I/O**。读写数据库是云函数的事，本目录只判定。

典型用法：

```js
const { canSteal } = require('./server-claude/src/steal');
const r = canSteal({
  thief, owner, plot,
  todayStealCount, todayStealOnOwner,
  guardUntil, guardRoll: Math.random(), now: Date.now(),
});
if (!r.ok) return { code: r.reason };
// r.yield 就是偷到几棵，接下来写库
```

## 拒绝原因（reason）对照

客户端按这些码显示文案，不要自己拼字符串。

| reason | 文案 |
| --- | --- |
| `own_plot` | 自己的地 |
| `not_ripe` | 还没熟 |
| `already_stolen` | 这格有人来过了 |
| `daily_limit` | 今天偷够了 |
| `house_limit` | 这家今天偷够了 |
| `guarded` | 喜多在看你 |
| `borrowed_today` | 今天借过了 |
| `no_seed` | 没种子了 |
| `plot_occupied` | 这格有东西 |
| `local_market_closed` | 双日不赶场 明天来 |
| `cannot_include_self` | 牵不了自己 |
| `same_person` | 得是两个人 |
| `weekly_quota` | 这周的两条用完了 |
| `already_friend` | 已经是好友了 |
| `already_tried` | 牵过一回了 |
| `drawn_today` | 今天求过了 |
| `no_stick_today` | 今天没签了 明天再来 |
| `self` | 不能给自己写 |
| `already_wrote` | 你写过了 |
| `full` | 写满了 |
| `too_far` | 隔太远了 |
| `kicked_this_ball` | 这个球今天踢过了 |

## 还没做（阶段 1 剩余）

- 云函数外壳（微信云开发的 `exports.main`）
- 敏感词校验（见 `docs/敏感词模块-需求.md`）
- 数据表定义与索引
- 定时触发器：镇报、每日重置、动物路线、球的位置

下一批我来写。
