extends RefCounted
## 席间小游戏的存档：金币、每个游戏通关到第几关、连连看解锁的菜、累计添进礼金的金币（蓝图 3.2，阿鱼 9/19 定）。
## 本机存一份（user://suqi_games.json，断网也不丢）；每次有变化就调 saver 存进住民资料（云函数 saveProfile 加的字段），
## 换手机进厅时 enterHall 带回来的 mine 为准。云上没存成功（dirty）时，下次进厅先把本机的推上去，不拿云上的旧数盖掉
## 金币只能玩出来，不能买（个人主体做不了内购，红线）；唯一去处是主桌添礼金（give_gift）

const LOCAL := "user://suqi_games.json"

var local_path := LOCAL        # 测试里改成别的文件，别写进真存档
var coins := 0
var games: Dictionary = {}      # 游戏 id -> 通关到第几关
var dishes: Array = []          # 连连看解锁的菜序号
var gift_coins := 0             # 累计添进礼金的金币
var dirty := false              # 有改动还没存进云上
var saver: Callable             # func(payload: Dictionary, done: Callable)，main 接到 cloud.call_fn("saveProfile")

func load_local() -> void:
    if not FileAccess.file_exists(local_path):
        return
    var d = JSON.parse_string(FileAccess.get_file_as_string(local_path))
    if typeof(d) != TYPE_DICTIONARY:
        return
    coins = int(d.get("coins", 0))
    games = d.get("games", {})
    dishes = d.get("dishes", [])
    gift_coins = int(d.get("gift_coins", 0))
    dirty = bool(d.get("dirty", false))

## 进厅时 enterHall 带回来的 mine：本机没有没存上的改动就以云上为准；有就把本机的推上去
func apply_cloud(mine: Dictionary) -> void:
    if dirty:
        _push({"coins": coins, "games": games, "dishes": dishes, "gift_coins": gift_coins})
        return
    coins = int(mine.get("coins", 0))
    var g = mine.get("games", {})
    games = g if typeof(g) == TYPE_DICTIONARY else {}
    var ds = mine.get("dishes", [])
    dishes = ds if typeof(ds) == TYPE_ARRAY else []
    gift_coins = int(mine.get("gift_coins", 0))
    _write_local()

func cleared(id: String) -> int:
    return int(games.get(id, 0))

func next_level(id: String) -> int:
    return cleared(id) + 1

## 通关：记进度、加金币，连连看顺带解锁一道菜（dish >= 0）
func clear_level(id: String, level: int, reward: int, dish := -1) -> void:
    games[id] = maxi(cleared(id), level)
    coins += maxi(reward, 0)
    var payload := {"coins": coins, "games": games}
    if dish >= 0 and not dishes.has(dish):
        dishes.append(dish)
        payload["dishes"] = dishes
    _push(payload)

## 别处挣的金币（果园把果子卖给山庄，阿鱼 9/20 定）：和小游戏同一个钱包，存法也一样
func earn(n: int) -> int:
    if n <= 0:
        return coins
    coins += n
    _push({"coins": coins})
    return coins

## 主桌添礼金：n 金从金币里扣、记进累计，服务端礼金簿记一笔。金币不够返回 false
func give_gift(n: int) -> bool:
    if n <= 0 or n > coins:
        return false
    coins -= n
    gift_coins += n
    _push({"coins": coins, "gift_coins": gift_coins, "gift_add": n})
    return true

## 花金币（阿鱼 9/20 定：全游戏消费都用金币）。现在只有宴会厅「添一道菜」40 金用它。
## 只买当场发生的那一下，不买属性、不买优势；金币不够返回 false，不欠账
func spend(n: int) -> bool:
    if n <= 0 or n > coins:
        return false
    coins -= n
    _push({"coins": coins})
    return true

## 调试版：跳关用（不给金币）
func debug_set_cleared(id: String, level: int) -> void:
    games[id] = maxi(level, 0)
    _push({"games": games})

var _seq := 0

func _push(payload: Dictionary) -> void:
    dirty = true
    _seq += 1
    var my := _seq
    _write_local()
    if saver.is_valid():
        saver.call(payload, func(ok: bool):
            # 只有最后一次存成功才算干净：前一次的「成功」晚到，不能把后一次没存上的也算成存好了
            if ok and my == _seq:
                dirty = false
                _write_local())

func _write_local() -> void:
    var f := FileAccess.open(local_path, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify({"coins": coins, "games": games, "dishes": dishes, "gift_coins": gift_coins, "dirty": dirty}))
