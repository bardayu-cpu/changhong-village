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

## 这张桌玩哪个游戏；没有返回 {}
static func game_for_table(table_id: String) -> Dictionary:
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
