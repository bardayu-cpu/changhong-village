extends RefCounted
## 席间小游戏的配置（蓝图 3.2，阿鱼 9/19 定）：assets/minigames/minigames.json
## 哪两桌玩哪个、每关难度怎么升、通关给多少金币、连连看解锁的菜、菜牌的颜色和字。改难度只改 json

const PATH := "res://assets/minigames/minigames.json"

static var _data: Dictionary = {}

static func data() -> Dictionary:
    if _data.is_empty():
        var d = JSON.parse_string(FileAccess.get_file_as_string(PATH))
        _data = d if typeof(d) == TYPE_DICTIONARY else {"games": []}
    return _data

static func game(id: String) -> Dictionary:
    for g in data().get("games", []):
        if str(g["id"]) == id:
            return g
    return {}

## 55 桌厅每桌一个游戏（01 D 9/30 v8）：桌号 -> 游戏 id，进 55 桌厅时 layered_hall 按北京日期排好；
## 空的就照 json 里各游戏的 tables（第 44 版厅 1～6 号桌）
static var daily: Dictionary = {}
static var daily_day := ""

## 这张桌玩哪个游戏；没有返回 {}
static func game_for_table(table_id: String) -> Dictionary:
    if not daily.is_empty():
        return game(str(daily[table_id])) if daily.has(table_id) else {}
    for g in data().get("games", []):
        if table_id in g.get("tables", []):
            return g
    return {}

## 桌牌、按钮上的名字：「吃席」（连连看）
static func title(g: Dictionary) -> String:
    return str(g.get("title", ""))

## 第 level 关的难度参数。k 是调试版的难度倍数（1 = 按表来）：hard=1 的参数乘 k，hard=-1 的除以 k
static func params(g: Dictionary, level: int, k := 1.0) -> Dictionary:
    var out := {}
    var lv: Dictionary = g.get("levels", {})
    for name in lv:
        out[name] = _value(lv[name], level, k)
    return out

## 第 level 关通关给多少金币
static func reward(g: Dictionary, level: int) -> int:
    return int(_value(g.get("reward", {"base": 10}), level, 1.0))

static func _value(p: Dictionary, level: int, k: float) -> float:
    var v := float(p.get("base", 0)) + float(p.get("step", 0)) * float(level - 1)
    var hard := int(p.get("hard", 0))
    if hard > 0:
        v *= k
    elif hard < 0 and k > 0.0:
        v /= k
    if p.has("min"):
        v = maxf(v, float(p["min"]))
    if p.has("max"):
        v = minf(v, float(p["max"]))
    if bool(p.get("int", false)):
        v = float(roundi(v))
    return v

static func dishes() -> Array:
    return data().get("dishes", [])

static func tiles() -> Array:
    return data().get("tiles", [])

# ---------- 55 桌厅：每桌随机一个游戏，按北京日期当种子 ----------
## 北京日期「2026-09-30」：拿 UTC 时间加 tz_hours 小时，不看手机时区（和亲友开席同一个算法）
static func beijing_day(unix: float, tz_hours := 8) -> String:
    return Time.get_date_string_from_unix_time(int(unix) + tz_hours * 3600)

## 进 55 桌厅时调：table_ids 按场景里的桌序，games 是能分的游戏 id，day 是北京日期
static func use_daily(table_ids: Array, games: Array, day: String) -> void:
    daily = daily_plan(table_ids, games, day)
    daily_day = day

## 回第 44 版厅：照 json 的 tables
static func clear_daily() -> void:
    daily = {}
    daily_day = ""

## 分法：三个游戏轮着排满 55 桌（各 18～19 桌，不会哪个游戏一天只有几桌），再按日期洗一遍。
## 种子和洗牌都是自己写的整数算法（FNV-1a + 线性同余），不用引擎的 hash()、随机数：
## 同一天、同一份桌号表，谁的手机、哪一版引擎算出来都一样
static func daily_plan(table_ids: Array, games: Array, day: String) -> Dictionary:
    var out := {}
    if games.is_empty():
        return out
    var slots: Array = []
    for i in table_ids.size():
        slots.append(games[i % games.size()])
    var s := _fnv(day) & 0x7fffffff
    for i in range(slots.size() - 1, 0, -1):
        s = (s * 1103515245 + 12345) & 0x7fffffff
        var j := (s >> 8) % (i + 1)
        var tmp = slots[i]
        slots[i] = slots[j]
        slots[j] = tmp
    for i in table_ids.size():
        out[str(table_ids[i])] = str(slots[i])
    return out

static func _fnv(text: String) -> int:
    var h := 2166136261
    for b in text.to_utf8_buffer():
        h = ((h ^ b) * 16777619) & 0xffffffff
    return h
