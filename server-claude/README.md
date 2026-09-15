# server-claude · 苏七镇奇缘服务端规则

> 作者：Claude。**Codex 请只读、只调用，不要修改本目录。**
> 有意见写进根目录 `IDEAS.md`。
> 对应文档：`docs/苏七镇-阶段1设计-v1.1.md`；踢球规则见 GDD v1.3 的 4.6

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
src/banquet.js   宴会厅「一场不散的席」：入座、换桌、敬酒、桌簿、进厅提示
test/rules.test.js  116 条测试，零依赖
scripts/sync-cf-rules.js  把 src/ 的规则文件复制进各云函数自己的 rules/ 文件夹，部署前必须先跑
cloudfunctions/login/       云函数：返回调用者的 openid，已部署到 cloud1-d9ggg36tj34742bef
cloudfunctions/initDb/      云函数：建宴会厅要用的 5 张数据表，还没部署（回执 02-建表与云函数）
cloudfunctions/enterHall/   云函数：进宴会厅，自动分座、进厅合并提示，还没部署
cloudfunctions/changeSeat/  云函数：换桌，还没部署
cloudfunctions/toast/       云函数：敬酒，还没部署
cloudfunctions/writeBook/   云函数：写桌簿，还没部署
cloudfunctions/readBook/    云函数：读桌簿，还没部署
cloudfunctions/saveProfile/ 云函数：存昵称/形象/邀请人/礼金/悄悄话，还没部署
```

## 云函数

`enterHall`、`changeSeat`、`toast`、`writeBook` 这几个用到 `src/` 里的规则文件，微信云函数按文件夹单独打包，
不能 require 文件夹外的代码，**部署前必须先跑一遍同步**（改了 src/ 也要重跑）：

```bash
node scripts/sync-cf-rules.js
```

部署单个函数（在任意目录执行，需要微信开发者工具已登录）：

```bash
/Applications/wechatwebdevtools.app/Contents/MacOS/cli cloud functions deploy --env cloud1-d9ggg36tj34742bef --paths "<本目录的完整路径>/cloudfunctions/login" --appid wx26cb1101e51f4a47 --remote-npm-install
```

把 `login` 换成要部署的函数名。第一次创建时如果报「当前函数处于 Creating 状态」，等二三十秒再执行一次。

**部署前先看 `回执/02-建表与云函数.md` 的函数列表，阿鱼点头后再部署（HANDOFF §0.6）。**

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
| `seat_taken` | 这把有人坐了 |
| `changed_today` | 今天换过了 明天再换 |
| `toast_limit` | 今天敬够了 |
| `toast_same_person` | 这杯敬过了 |
| `not_sat_here` | 先坐下 慢慢写 |
| `book_too_long` | 太长啦 真实情感的话 短一点也没关系 |
| `toast_self` | 自己就不用敬了 |

## 还没做（阶段 1 剩余）

- 宴会厅数据表和 6 个云函数已经写好，**还没部署、没建表**，见 `回执/02-建表与云函数.md`
- 敏感词校验（见 `docs/敏感词模块-需求.md`），`writeBook` 云函数先不判，等模块做出来接
- 其余功能（迎宾院签到、偷菜、月老庙等）对应的云函数外壳还没写
- 定时触发器：镇报、每日重置、动物路线、球的位置

下一批我来写。
