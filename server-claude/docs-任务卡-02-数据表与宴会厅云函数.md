# 任务卡 02 · 数据表与宴会厅云函数

> 写给：程序（Sonnet 5）
> 作者：Fable 5.1（总策划）
> 日期：2026-09-15
> 依据：《罗曼山庄-第一关蓝图-v0.2》2.4 存什么、3.2 宴会厅；`server-claude/README.md` 的纯函数约定；HANDOFF §0
> 阿鱼 9/15 晚已同意建表（§0.6）。云环境 cloud1-d9ggg36tj34742bef，部署命令见 server-claude/README.md。**部署前把要部署的函数列给阿鱼看一眼**

## 目标

把宴会厅「一场不散的席」的规则写成纯函数并测过，建好数据表，写好云函数，主程接试点时能直接调。

## 输入

- 蓝图 3.2 的功能需求和异常处理表，规则数字都在那里
- 现有 `server-claude/src/` 的写法：同步纯函数、随机数和时间由调用方传、不做 I/O
- 现有 `cloudfunctions/login`

## 输出

### 1. 规则：`server-claude/src/banquet.js`

| 函数 | 判什么 |
| --- | --- |
| `assignSeat({me, inviter, tables, seats})` | 第一次进厅坐哪：邀请人那桌 → 同枝下一桌 → 阿鱼和 Toretto 的枝坐前两桌 → 无邀请人坐任意空桌 → 邀请人没坐过就开一桌 → 120 满了坐长凳 |
| `canChangeSeat({me, seat, todayChanges, now})` | 每次来访换一次；目标椅子空 |
| `canToast({from, to, todayToasts, todayToastsTo, now})` | 每天 5 杯、同一人每天 1 杯、不能敬自己 |
| `canWriteBook({me, table, satTables, text})` | 坐过的桌才能写；≤100 字；敏感词走现有模块 |
| `arrivalDigest({toasts, bookLines, since})` | 进厅合并提示：「老王敬了你一杯，簿子上多了 2 句」的数据 |

拒绝原因加到 README 的对照表：`seat_taken`、`changed_today`、`toast_limit`、`toast_same_person`、`not_sat_here`、`book_too_long`。文案按蓝图 3.2 异常表。

参数进 `config.js`：每桌 10 座、12 桌、每天 5 杯、每次来访换 1 次、簿子 100 字。

### 2. 测试：`test/rules.test.js` 追加

每个函数至少 4 条：正常、上限、边界（跨北京时间 0 点）、异常。全部过，总数写进回执。

### 3. 数据表（云开发数据库）

| 表 | 字段 | 说明 |
| --- | --- | --- |
| resident | openid、nick、avatar、inviter（openid 或空）、created_at、gift_value、whisper、checked_in_at | 住民。gift_value 和 whisper 只有阿鱼后台读 |
| seat | openid、table_id、chair_no、sat_at、changed_on（日期） | 一人一条，换桌覆盖 |
| toast | from、to、date、created_at | 敬酒记录 |
| guestbook | table_id、openid、text、created_at | 桌簿 |
| friend_request | from、to、created_at、status | 阶段 1 只记，不处理 |

权限：全部「仅创建者可读写」之外，读座位、簿子、敬酒要经云函数。不开客户端直读。

### 4. 云函数

| 函数 | 做什么 |
| --- | --- |
| `enterHall` | 读或分配座位；返回本厅所有座位、桌牌、进厅合并提示 |
| `changeSeat` | 换桌 |
| `toast` | 敬酒 |
| `writeBook` / `readBook` | 写簿子、读一桌的簿子 |
| `saveProfile` | 昵称、形象、邀请人、签到礼金、悄悄话 |

每个函数先调 `banquet.js` 判定，通过才写库。返回 `{ok, reason, data}`，reason 用上面的码。

### 5. 回执：`server-claude/回执/02.md`

写：测试条数和结果、表结构最终版、云函数列表、没做的、要阿鱼确认的。

## 验收

1. `node test/rules.test.js` 全过
2. 云函数在开发者工具里本地调用能通；部署到线上要先经阿鱼点头
3. 主程拿 `enterHall` 的返回就能画出谁坐哪桌，不用再查别的

## 固定要求

1. 只做卡上的事，想加的写进 `IDEAS.md`
2. 做不了的停下来报告，不绕过
3. 不改 `godot/`，不改设计文档；规则和蓝图对不上时写进回执，不自己改规则
4. 任何密钥不写进仓库
5. 文案只从蓝图 3.2 取，不自己写
6. 一次提交一件事
