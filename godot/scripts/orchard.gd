extends "res://scripts/entrance.gd"
## 罗曼山庄 · 果园（蓝图 3.6，灰盒，01 9/20 派任务 10）：西边八条草莓垄，东边六棵枇杷树（两行三列），
## 中间一条小路从南口通到北边田埂，北边 y 0～200 是田埂和远处的田、不能走。
## 搭法、走路、交互点和迎宾院一样（entrance.gd，布局 assets/layered/scene_luoman_orchard/layout.json），这里多的是按季节结果：
##   有果的月份在 assets/orchard/seasons.json（草莓 12～4 月、枇杷 4～6 月，蓝图标了待验证，可调）；
##   到季节垄上才有红的、树上才有黄的，走到跟前出「摘一颗」；没到季节出「还没到时候」，按钮不出（蓝图 3.6）；
##   每天每种只能摘一颗，记在本机（orchard_save.gd）；摘了播一下小动作、说一句，没有奖励、不进背包、不上服务器；
##   日期早于 seasons.json 的 min_year（2026）按当季无果算（蓝图 3.6 异常处理）
## 测试、截图要看别的季节：把 fake_today 设成 "2026-12-05" 这样的日期就行

const SEASONS := "res://assets/orchard/seasons.json"
const KINDS := ["strawberry", "loquat"]
const PICK_SECS := 0.45          # 摘一下的小动作多久

var seasons: Dictionary = {}
var fake_today := ""             # 不是空串就当成今天（测试、截图用）；空串按这台机器的日期
var save                         # orchard_save.gd，main 建好塞进来
var fruit_nodes: Dictionary = {} # 果子 -> [Node2D]：到季节才显示
var pick_t := 0.0                # 摘的小动作还剩多久

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_orchard/layout.json"

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset, nickname, f)
    var cfg = JSON.parse_string(FileAccess.get_file_as_string(SEASONS))
    seasons = cfg if cfg is Dictionary else {}
    _make_fruit()
    refresh_fruit()

## 今天（本地日期，YYYY-MM-DD）
func today() -> String:
    if fake_today != "":
        return fake_today
    var d := Time.get_date_dict_from_system()
    return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

## 这种果子这天有没有（蓝图 3.6：按手机日期，月份表可调；min_year 以前的日期按当季无果）
static func in_season(kind: String, day: String, cfg: Dictionary) -> bool:
    var parts := day.split("-")
    if parts.size() < 2:
        return false
    if int(parts[0]) < int(cfg.get("min_year", 2026)):
        return false
    var fruits: Dictionary = cfg.get("fruits", {})
    var months: Array = (fruits.get(kind, {}) as Dictionary).get("months", [])
    var month := int(parts[1])
    for mo in months:
        # json 里的数字读进来是小数（12.0），Godot 的 in、has 又是认类型的（12 in [12.0] 是 false），所以挨个转成整数比
        if int(mo) == month:
            return true
    return false

## 今天这种摘过没有
func picked_today(kind: String) -> bool:
    return save != null and save.picked_on(kind) == today()

## 现在能不能摘：到季节、今天还没摘过
func can_pick(kind: String) -> bool:
    return in_season(kind, today(), seasons) and not picked_today(kind)

## 摘一颗：本机记一笔，垄上（树上）少一颗，人弯一下腰
func pick(kind: String) -> bool:
    if not can_pick(kind):
        return false
    if save != null:
        save.mark(kind, today())
    pick_t = PICK_SECS
    for n in fruit_nodes.get(kind, []):
        if (n as Node2D).visible:
            (n as Node2D).visible = false     # 摘掉的那一颗不见了
            break
    print("[suqi] 果园 摘了一颗 ", kind, " ", today())
    return true

## 到季节的才显示（换了日期、摘过以后都对一次）
func refresh_fruit() -> void:
    for kind in KINDS:
        var on := in_season(kind, today(), seasons)
        var gone := picked_today(kind)
        var list: Array = fruit_nodes.get(kind, [])
        for i in list.size():
            # 今天摘过的那种：少画一颗，看得出摘走了
            (list[i] as Node2D).visible = on and not (gone and i == 0)

# ---------- 果子（灰盒占位：垄上的红点、树上的黄点） ----------
func _make_fruit() -> void:
    var straw: Array = []
    var loquat: Array = []
    var rng := RandomNumberGenerator.new()
    rng.seed = 926
    for it in cfg.get("items", []):
        var id := str(it.get("id", ""))
        if id.begins_with("ridge_"):
            var r: Array = it["rect"]
            var foot := float(r[3])
            for k in 9:
                var x := lerpf(float(r[0]) + 30.0, float(r[2]) - 30.0, float(k) / 8.0) + rng.randf_range(-8.0, 8.0)
                straw.append(_fruit_dot(Vector2(x, foot), Color("#d33b2f"), 5.0, -6.0))
        elif id.begins_with("loquat_"):
            var tx := float(it["x"])
            var ty := float(it["y"])
            var tr := float(it["r"])
            for k in 7:
                var a := TAU * float(k) / 7.0
                loquat.append(_fruit_dot(Vector2(tx + cos(a) * tr * 0.55, ty), Color("#e8a33d"), 4.5, -46.0 - tr * 0.7 + sin(a) * tr * 0.45))
    fruit_nodes = {"strawberry": straw, "loquat": loquat}

## 一颗果子：画在着地点上方 dy 的地方，按脚点排前后（垄、树都在同一块画布里）
func _fruit_dot(at: Vector2, col: Color, r: float, dy: float) -> Node2D:
    var holder := Node2D.new()
    holder.position = at
    holder.add_child(_poly(_ellipse_pts(0.0, dy, r, r * 0.9, 10), col))
    holder.add_child(_poly(_ellipse_pts(-r * 0.3, dy - r * 0.35, r * 0.28, r * 0.25, 6), Color(1, 1, 1, 0.5)))
    world.add_child(holder)
    return holder

func _process(dt: float) -> void:
    super(dt)
    # 摘的小动作（蓝图 3.6 交互说明「摘了播一个短动作」）：弯一下腰再起来，灰盒先这样
    if pick_t > 0.0:
        pick_t = maxf(pick_t - dt, 0.0)
        var k := 1.0 - absf(pick_t / PICK_SECS - 0.5) * 2.0
        player.offset.y += k * 5.0
