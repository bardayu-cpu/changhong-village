extends "res://scripts/entrance.gd"
## 罗曼山庄 · 果园（蓝图 3.6 的地方 + 阿鱼 9/20 定的种田玩法）：西边八条草莓垄，东边六棵枇杷树（两行三列），
## 中间一条小路从南口通到北边田埂，北边 y 0～200 是田埂和远处的田、不能走。
## 搭法、走路、交互点和迎宾院一样（entrance.gd，布局 assets/layered/scene_luoman_orchard/layout.json），这里多的是种田那套：
##   每条垄、每棵树各算一块地，各自计时；一轮 5 分钟（assets/orchard/farm.json 的 grow_secs，改数不改代码）
##   光地 → 长到一半变青果 → 熟了（草莓红、枇杷黄）。按真实时钟算，人不在也长：关了游戏过 5 分钟回来，该熟的已经熟了
##   走到垄间、树下：有熟的出「收草莓（N 垄熟了）」，一下收完那种所有熟的，进果篮；没熟顶部报还有多久
##   收完山庄直接折成金币（sell_mode 默认 auto，01 9/20 定），金币进和小游戏同一个钱包（game_save → saveProfile）；
##   改成 manual 就是先进果篮、走到「山庄收购处」再卖，摊子和 shop 交互点两种模式都在
##   【熟了不叠，01 9/20 定】地熟了就停着等人收，不接着攒：挂多久回来都是一轮的量（见 ripeness 封顶）。
##   没有加速成熟、立刻收获这类口子——金币只能玩出来（第 28 版验收清单第 15 条）
##   season_gate 打开才按蓝图 3.6 的真实月份（草莓 12～4、枇杷 4～6，seasons.json），默认关——5 分钟一轮和等几个月的季节对不上
## 测试、截图要拨时间：fake_now 设成秒数就按那个时刻算；老的季节玩法要试就 fake_today + season_gate

const SEASONS := "res://assets/orchard/seasons.json"
const FARM := "res://assets/orchard/farm.json"
const KINDS := ["strawberry", "loquat"]
const PICK_SECS := 0.45          # 收一下的小动作多久
const REFRESH_SECS := 0.5        # 站在果园里多久对一次地（果子该长的长、倒计时该跳的跳）
const RIPE_COL := {"strawberry": Color("#d33b2f"), "loquat": Color("#e8a33d")}
const GREEN_COL := Color("#7fa83f")

var seasons: Dictionary = {}
var farm: Dictionary = {}
var fake_today := ""             # 不是空串就当成今天（只有季节开关打开时才用得上）
var fake_now := -1.0             # 大于 0 就当成现在几点（秒），测试、截图拨时间用
var save                         # orchard_save.gd，main 建好塞进来
var plots: Array = []            # [{id, kind, dots:[Node2D], bodies:[Polygon2D]}]
var pick_t := 0.0                # 收的小动作还剩多久
var _refresh_t := 0.0

func _init() -> void:
    layout_path = "res://assets/layered/scene_luoman_orchard/layout.json"

func build(preset: int, nickname: String, f: Font) -> void:
    super(preset, nickname, f)
    seasons = _read(SEASONS)
    farm = _read(FARM)
    _make_plots()
    refresh_fruit()

func _read(path: String) -> Dictionary:
    var d = JSON.parse_string(FileAccess.get_file_as_string(path))
    return d if d is Dictionary else {}

# ---------- 时间 ----------

## 现在几点（秒）。测试里把 fake_now 设成别的时刻，就能看见果子长大
func now() -> float:
    return fake_now if fake_now > 0.0 else Time.get_unix_time_from_system()

## 今天（本地日期）——只有季节开关打开时才用
func today() -> String:
    if fake_today != "":
        return fake_today
    var d := Time.get_date_dict_from_system()
    return "%04d-%02d-%02d" % [int(d["year"]), int(d["month"]), int(d["day"])]

func grow_secs() -> float:
    return maxf(float(farm.get("grow_secs", 300.0)), 1.0)

func auto_sell() -> bool:
    return str(farm.get("sell_mode", "manual")) == "auto"

## 要不要按真实月份（蓝图 3.6 的老玩法，默认关）
func season_on() -> bool:
    return bool(farm.get("season_gate", false))

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

## 季节开关关着的时候，什么时候来都长
func kind_on(kind: String) -> bool:
    return not season_on() or in_season(kind, today(), seasons)

# ---------- 地长到哪一步了 ----------

## 这块地长了几成（1 以上就是熟了）。没收过的地当早就熟了：头一回进果园就有的收。
## 【熟了不叠，01 9/20 定的底线】封顶在 1：地熟了就停在那儿等人收，不会接着攒。
## 挂一天回来也还是 14 块地、一轮的量——产出由「来几次」定，不由「挂多久」定
func ripeness(plot_id: String) -> float:
    if save == null:
        return 1.0
    var at: float = save.picked_at(plot_id)
    if at < 0.0:
        return 1.0
    return clampf((now() - at) / grow_secs(), 0.0, 1.0)

## 0 光地、1 青果、2 熟了
func stage_of(plot_id: String, kind: String) -> int:
    if not kind_on(kind):
        return 0
    var r := ripeness(plot_id)
    if r >= 1.0:
        return 2
    return 1 if r >= float(farm.get("green_at", 0.5)) else 0

## 这种果子熟了几块地
func ripe_count(kind: String) -> int:
    var n := 0
    for p in plots:
        if p["kind"] == kind and stage_of(p["id"], kind) == 2:
            n += 1
    return n

## 这种果子最快还有多久熟（都熟了返回 0；季节关着返回 -1）
func secs_left(kind: String) -> float:
    if not kind_on(kind):
        return -1.0
    var best := -1.0
    for p in plots:
        if p["kind"] != kind:
            continue
        var left := (1.0 - ripeness(p["id"])) * grow_secs()
        if left <= 0.0:
            return 0.0
        if best < 0.0 or left < best:
            best = left
    return maxf(best, 0.0)

## 还有多久，说成人话
static func left_text(secs: float) -> String:
    var s := int(ceil(maxf(secs, 0.0)))
    if s < 60:
        return "%d 秒" % s
    return "%d 分 %d 秒" % [s / 60, s % 60]

# ---------- 收和卖 ----------

## 把这种果子熟了的地一次收完，进果篮。返回收了几份（一块地几份看 farm.json 的 yield）
func harvest(kind: String) -> int:
    var got := 0
    var per := int(_fruit(kind).get("yield", 1))
    for p in plots:
        if p["kind"] != kind or stage_of(p["id"], kind) != 2:
            continue
        save.mark_plot(p["id"], now())   # 收完这块地重新开始长
        got += per
    if got <= 0:
        return 0
    save.add_basket(kind, got)
    save.save()
    pick_t = PICK_SECS
    refresh_fruit()
    print("[suqi] 果园 收了 ", got, " 份 ", kind)
    return got

## 果篮里现在值多少金币
func basket_coins() -> int:
    var c := 0
    for kind in KINDS:
        c += save.basket_of(kind) * int(_fruit(kind).get("price", 0))
    return c

## 果篮里都有什么，说成人话（「草莓 3 筐 枇杷 2 篮」）
func basket_text() -> String:
    var parts: Array = []
    for kind in KINDS:
        var n: int = save.basket_of(kind)
        if n > 0:
            parts.append("%s %d %s" % [_fruit(kind).get("name", kind), n, _fruit(kind).get("unit", "份")])
    return " ".join(parts)

## 卖给山庄：清空果篮，返回 {n: 几份, coins: 多少金, text: 都卖了什么}。金币由 main 加进钱包
func sell() -> Dictionary:
    var n: int = save.basket_total()
    if n <= 0:
        return {"n": 0, "coins": 0, "text": ""}
    var out := {"n": n, "coins": basket_coins(), "text": basket_text()}
    save.clear_basket()
    save.save()
    print("[suqi] 果园 卖了 ", out["text"], " 得 ", out["coins"], " 金")
    return out

func _fruit(kind: String) -> Dictionary:
    var fruits: Dictionary = farm.get("fruits", {})
    var d = fruits.get(kind, {})
    return d if d is Dictionary else {}

func fruit_name(kind: String) -> String:
    return str(_fruit(kind).get("name", kind))

func plot_word(kind: String) -> String:
    return str(_fruit(kind).get("plot", "块"))

## 一份叫什么（草莓一筐、枇杷一篮）
func basket_unit(kind: String) -> String:
    return str(_fruit(kind).get("unit", "份"))

# ---------- 地里的果子（灰盒占位：垄上的点、树上的点） ----------

func _make_plots() -> void:
    var rng := RandomNumberGenerator.new()
    rng.seed = 926
    plots = []
    for it in cfg.get("items", []):
        var id := str(it.get("id", ""))
        var dots: Array = []
        var bodies: Array = []
        if id.begins_with("ridge_"):
            var r: Array = it["rect"]
            var foot := float(r[3])
            for k in 9:
                var x := lerpf(float(r[0]) + 30.0, float(r[2]) - 30.0, float(k) / 8.0) + rng.randf_range(-8.0, 8.0)
                var pair := _fruit_dot(Vector2(x, foot), RIPE_COL["strawberry"], 5.0, -6.0)
                dots.append(pair[0])
                bodies.append(pair[1])
            plots.append({"id": id, "kind": "strawberry", "dots": dots, "bodies": bodies})
        elif id.begins_with("loquat_"):
            var tx := float(it["x"])
            var ty := float(it["y"])
            var tg := tree_geom(it)   # 果子挂在树冠上（树按「人 = 1」改大以后跟着走，10/3）
            for k in 7:
                var a := TAU * float(k) / 7.0
                var pair2 := _fruit_dot(Vector2(tx + cos(a) * float(tg["rx"]) * 0.55, ty), RIPE_COL["loquat"], 4.5,
                    float(tg["cy"]) - ty + sin(a) * float(tg["ry"]) * 0.53)
                dots.append(pair2[0])
                bodies.append(pair2[1])
            plots.append({"id": id, "kind": "loquat", "dots": dots, "bodies": bodies})

## 一颗果子：画在着地点上方 dy 的地方，按脚点排前后（垄、树都在同一块画布里）。返回 [整颗, 果肉那块]
func _fruit_dot(at: Vector2, col: Color, r: float, dy: float) -> Array:
    var holder := Node2D.new()
    holder.position = at
    var body := _poly(_ellipse_pts(0.0, dy, r, r * 0.9, 10), col)
    holder.add_child(body)
    holder.add_child(_poly(_ellipse_pts(-r * 0.3, dy - r * 0.35, r * 0.28, r * 0.25, 6), Color(1, 1, 1, 0.5)))
    world.add_child(holder)
    return [holder, body]

## 手机时间往回拨（蓝图 3.6 异常处理）：哪块地的时刻比现在还晚，就从现在重算，不结算负数、也不会白等一年
func _fix_clock() -> void:
    if save == null:
        return
    var t := now()
    var fixed := false
    for p in plots:
        if save.picked_at(p["id"]) > t:
            save.mark_plot(p["id"], t)
            fixed = true
    if fixed:
        save.save()
        print("[suqi] 果园 手机时间往回拨了，地从现在重算")

## 照每块地长到哪一步，把果子改成看得出来的样子：光地没有、青果绿的小一点、熟了原色
func refresh_fruit() -> void:
    _fix_clock()
    for p in plots:
        var st := stage_of(p["id"], p["kind"])
        var col: Color = GREEN_COL if st == 1 else RIPE_COL[p["kind"]]
        var sc := 0.7 if st == 1 else 1.0
        for i in (p["dots"] as Array).size():
            var dot := p["dots"][i] as Node2D
            dot.visible = st > 0
            dot.scale = Vector2(sc, sc)
            (p["bodies"][i] as Polygon2D).color = col

func _process(dt: float) -> void:
    super(dt)
    # 站在果园里也会长：每半秒对一次地
    _refresh_t += dt
    if _refresh_t >= REFRESH_SECS:
        _refresh_t = 0.0
        refresh_fruit()
    # 收的小动作：弯一下腰再起来，灰盒先这样
    if pick_t > 0.0:
        pick_t = maxf(pick_t - dt, 0.0)
        var k := 1.0 - absf(pick_t / PICK_SECS - 0.5) * 2.0
        player.offset.y += k * 5.0
