extends RefCounted
## 果园存在本机的（阿鱼 9/20 定的种田玩法）：每块地上次收是什么时候、果篮里现在有什么。
## 时间存的是真实时钟（秒），所以人不在也照样长——关了游戏过 5 分钟回来，该熟的已经熟了。
## 金币不存这里：卖掉那一下加进 game_save（和小游戏同一个钱包，跟着 saveProfile 存住民资料）

const LOCAL := "user://suqi_orchard.json"

var local_path := LOCAL       # 测试里改成别的文件，别写进这台机器上的真存档
var plots: Dictionary = {}    # 地的编号（ridge_0、loquat_1_2……）-> 上次收走的时刻（秒）
var basket: Dictionary = {}   # 果子 -> 果篮里有几份（还没卖的）
var sold: Dictionary = {}     # 果子 -> 一共卖过几份（给以后看着玩，不影响玩法）

func load_local() -> void:
    if not FileAccess.file_exists(local_path):
        return
    var d = JSON.parse_string(FileAccess.get_file_as_string(local_path))
    if not (d is Dictionary):
        return
    # 旧存档（按季节、每天摘一颗那版）里只有 picked，没有这几样：当没收过，地一进去就是熟的
    plots = _num_dict(d.get("plots", {}))
    basket = _num_dict(d.get("basket", {}))
    sold = _num_dict(d.get("sold", {}))

func save() -> void:
    var f := FileAccess.open(local_path, FileAccess.WRITE)
    if f == null:
        return
    f.store_string(JSON.stringify({"plots": plots, "basket": basket, "sold": sold}))
    f.close()

## 这块地上次收是什么时候（没收过返回 -1：当它早就熟了，头一回来就有的摘）
func picked_at(plot: String) -> float:
    return float(plots.get(plot, -1.0))

func mark_plot(plot: String, at: float) -> void:
    plots[plot] = at

## 收进果篮
func add_basket(kind: String, n: int) -> void:
    basket[kind] = int(basket.get(kind, 0)) + n

func basket_of(kind: String) -> int:
    return int(basket.get(kind, 0))

func basket_total() -> int:
    var n := 0
    for k in basket:
        n += int(basket[k])
    return n

## 卖空果篮，记一笔卖过多少
func clear_basket() -> void:
    for k in basket:
        sold[k] = int(sold.get(k, 0)) + int(basket[k])
    basket = {}

## json 读回来的数字都是小数，统一成能算的字典。
## 存档要是被改花了（null、又套一层字典这类），那一项直接丢掉不要：
## 脚本本来就不会崩、兜底也是「这块地没收过」，但日志里别留红字，以后排查碍事（01 9/20，03 提）
func _num_dict(d) -> Dictionary:
    var out := {}
    if d is Dictionary:
        for k in d:
            var v = d[k]
            if v is float or v is int:
                out[str(k)] = float(v)
    return out
