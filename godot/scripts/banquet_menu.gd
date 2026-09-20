extends RefCounted
## 宴会厅的席面菜单（阿鱼 9/20 定：中午正席、晚上晚宴，两套都是婚礼当天真实的菜；点一道菜当场看简介，不切场景）。
## 菜名、简介、几点切、添菜多少钱全在 assets/banquet/menu.json，改字改数不改代码。
## 菜名是阿鱼 9/20 认过的定稿，别动；简介是 02 拟的草稿，等阿鱼定；酒店自己起名的两道没瞎猜，留「【待补】」。
## 「添一道菜」（玩法过目-金币花在哪 第一样）的数和能添哪几道也在这份 json 里：
##   40 金一道；一开始能添 always 那三道，菜单册（打「连连看」那两桌）解锁过的也能添。
## 测试、截图拨时间：fake_hour 设成 0～23 就当成那个点，-1 是按手机的真实时间。

const PATH := "res://assets/banquet/menu.json"

var d: Dictionary = {}
var fake_hour := -1        # 0～23 当成现在几点；-1 按真实时间

func _init() -> void:
    var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
    d = j if j is Dictionary else {}

# ---------- 哪一套 ----------

## 现在几点（0～23）。测试里 fake_hour 说了算
func hour_now() -> int:
    if fake_hour >= 0:
        return fake_hour % 24
    return int(Time.get_datetime_dict_from_system()["hour"])

## 现在该上哪一套：阿鱼 9/20 定的 12:00～18:00 正席、其余晚宴。几点切在 json 的 switch 里，改钟点不改代码
func menu_key() -> String:
    var sw: Dictionary = d.get("switch", {})
    var h := hour_now()
    var midday := int(sw.get("midday_from", 12))
    var evening := int(sw.get("evening_from", 18))
    return "midday" if h >= midday and h < evening else "evening"

func _menu(key := "") -> Dictionary:
    var k := key if key != "" else menu_key()
    return (d.get("menus", {}) as Dictionary).get(k, {})

## 这一套叫什么：「正席」「晚宴」
func title(key := "") -> String:
    return str(_menu(key).get("title", ""))

## 这一套有哪些菜，按单子上的顺序
func dishes(key := "") -> Array:
    var ds = _menu(key).get("dishes", [])
    return ds if ds is Array else []

## 这道菜的简介；还没写的返回空串（界面上显示「【待补】」）
func intro(name: String) -> String:
    return str((d.get("intros", {}) as Dictionary).get(name, ""))

func line(key: String) -> String:
    return str(((d.get("lines", {}) as Dictionary).get(key, {}) as Dictionary).get("text", key))

# ---------- 添一道菜 ----------

func add_price() -> int:
    return int((d.get("add_dish", {}) as Dictionary).get("price", 40))

## 一张桌上最多摆几道自己添的菜
func add_max() -> int:
    return int((d.get("add_dish", {}) as Dictionary).get("max_on_table", 4))

## 一开始就能添的那几道（不用解锁）
func always_dishes() -> Array:
    var a = (d.get("add_dish", {}) as Dictionary).get("always", [])
    return a if a is Array else []

## 能添哪些菜：always 那三道 + 菜单册里解锁过的（连连看每过一关解一道）。
## book 是 minigames.json 的 dishes 那张表，unlocked 是存档里解开的序号
func addable(book: Array, unlocked: Array) -> Array:
    var out: Array = []
    for n in always_dishes():
        var s := str(n)
        if not out.has(s):
            out.append(s)
    for i in book.size():
        # json 里的数字读进来是小数：12 in [12.0] 是 false，挨个 int() 比
        var got := false
        for u in unlocked:
            if int(u) == i:
                got = true
                break
        if not got:
            continue
        var nm := str((book[i] as Dictionary).get("name", ""))
        if nm != "" and not out.has(nm):
            out.append(nm)
    return out

## 菜单册里没解开的那些（面板上灰着显示，让人知道打游戏能解出来）
func locked_dishes(book: Array, unlocked: Array) -> Array:
    var always := always_dishes()
    var out: Array = []
    for i in book.size():
        var got := false
        for u in unlocked:
            if int(u) == i:
                got = true
                break
        if got:
            continue
        var nm := str((book[i] as Dictionary).get("name", ""))
        if nm != "" and not always.has(nm):
            out.append(nm)
    return out
