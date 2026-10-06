extends SceneTree
## 验收：罗曼山庄果园（地方照蓝图 3.6，玩法按阿鱼 9/20 定的种田循环）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 9/20 加高（01 派任务 11）：画布 1536×1280，顶上 256 像素是纯风景带（远处的田，人走不到），玩法区整体 +256，下面的坐标都是加过的。
## 布局：蓝图 3.6 那三个交互点照蓝图 +256，另加「山庄收购处」；八条草莓垄、六棵枇杷树、中间小路、北边田埂不能走；人在垄间走得开。
## 种田：八条垄 + 六棵树 = 14 块地各自计时，一轮 300 秒（assets/orchard/farm.json，改数不改代码）；
##   光地 → 长一半变青果 → 熟；按真实时钟算，人不在也长（关了游戏回来该熟的熟了）；
##   【熟了不叠，01 9/20 定的底线】挂多久回来都是 14 块地、一轮的量；
##   走到垄间、树下有熟的出「收草莓（N 垄熟了）」，一次收完；默认 sell_mode=auto，山庄直接折成金币；
##   改 manual 就先进果篮、走到收购处再卖；金币进和小游戏同一个钱包，存法走现成的 saveProfile，不新增云函数；
##   season_gate 打开才按蓝图 3.6 的真实月份（默认关）
## 进出：草坪北口 ↔ 果园南口，到了站的点离出口至少 1 米、不来回弹
## 用法：Godot --headless --path . --script res://tools/test_orchard.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Orchard = preload("res://scripts/orchard.gd")
const OrchardSave = preload("res://scripts/orchard_save.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0
const SAVE_PATH := "user://test_orchard.json"

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 20.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

## 站到交互点旁边（不在半径里），再走进去：这样进出的信号才会发
func walk_into(o, id: String, from: Vector2) -> void:
    o.reset_to(from)
    tick(1)
    walk_to(o.spot_pos(id))

## 把所有地拨成「上次收是 age 秒以前」
func age_all(o, age: float) -> void:
    for p in o.plots:
        m.orchard_save.mark_plot(p["id"], o.now() - age)
    o.refresh_fruit()

func stage_count(o, kind: String, st: int) -> int:
    var n := 0
    for p in o.plots:
        if p["kind"] == kind and o.stage_of(p["id"], kind) == st:
            n += 1
    return n

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    # 后厅、草坪、湖边、果园开场不搭、第一次进去才搭（main.ensure_canvas，02 10/3）：这里要直接看它们，先搭好
    for cn in ["backhall", "lawn", "lake", "orchard"]:
        m.ensure_canvas(cn)
    await process_frame
    var o = m.orchard
    var l = m.lawn
    var ui = m.orchard_ui
    m.games_save.local_path = "user://test_orchard_games.json"
    m.court_save.local_path = "user://test_orchard_court.json"
    m.orchard_save.local_path = SAVE_PATH
    m.orchard_save.plots = {}
    m.orchard_save.basket = {}
    m.orchard_save.sold = {}
    o.fake_now = 1_800_000_000.0      # 从一个定死的时刻起算（真实纪元的量级，往回拨也不会变成负数），省得跟着真钟走

    # 1. 布局：蓝图 3.6 的三个点没动，另加收购处
    print("1 布局")
    # 10/4 连图（02 E 改）：果园原地切成西 A 草莓、东 B 枇杷；A、B 各一个南口去草坪，A 西口去湖边，B 北口去后门
    # 10/4 方案 C：重摆成西 B 枇杷、东 A 草莓（地面左右翻、东西按中心挪到 1536 − x），A 东口去湖边，B 北口去后门
    var want := {"strawberry": [1136, 796, 60], "loquat": [386, 756, 60], "to_lawn": [1116, 1136, 60], "to_lawn_b": [386, 1136, 60],
        "to_lake": [800, 470, 40], "to_backgate": [536, 470, 44]}   # 10/4 湖边西半边接图：去湖边的口挪到北边中间小路北头
    var same: bool = o.points.size() == 7
    for id in want:
        same = same and o.points.has(id) and o.points[id]["pos"] == Vector2(want[id][0], want[id][1]) and is_equal_approx(float(o.points[id]["r"]), float(want[id][2]))
    check("蓝图 3.6 那几个点（10/4 加了 A、B 两个南口和去湖边、后门的口）一字不差，另加了收购处", same and o.points.has("shop"))
    check("收购处站得住、和南口不重叠（离 %.0f 像素）" % o.points["shop"]["pos"].distance_to(o.points["to_lawn"]["pos"]),
        o._free(o.points["shop"]["pos"]) and o.points["shop"]["pos"].distance_to(o.points["to_lawn"]["pos"]) > float(o.points["shop"]["r"]) + float(o.points["to_lawn"]["r"]))
    var land_ok := true
    for id in ["to_lawn", "to_lawn_b", "to_lake", "to_backgate"]:
        if o.arrival_at(id).distance_to(o.points["shop"]["pos"]) <= float(o.points["shop"]["r"]):
            land_ok = false
    check("从各口进来站的点都不会正好踩在收购处圈里", land_ok)
    var ridges := 0
    var trees := 0
    for p in o.plots:
        if p["kind"] == "strawberry":
            ridges += 1
        else:
            trees += 1
    check("八条草莓垄、六棵枇杷树，各算一块地（%d + %d = %d 块）" % [ridges, trees, o.plots.size()], ridges == 8 and trees == 6)
    var gap_walk := 0
    for y in [592, 660, 728, 796, 864, 932, 1000]:
        if o._free(Vector2(1136, y)):
            gap_walk += 1
    check("垄间走得开（七条空道能站 %d 条）" % gap_walk, gap_walk == 7)
    check("北边田埂、远处的田、顶上那条风景带都不能走", not o._free(Vector2(768, 406)) and not o._free(Vector2(300, 356))
        and not o._free(Vector2(768, 120)) and not o._free(Vector2(200, 60)))
    for id in o.points:
        var pt: Vector2 = o.points[id]["pos"]
        var path: Array = o.find_path(o.SPAWN, pt)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else o.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(pt), o.points[id]["r"]], end.distance_to(pt) < float(o.points[id]["r"]))

    # 2. farm.json 的默认（01 9/20 定）
    print("2 默认")
    check("一轮 %.0f 秒" % o.grow_secs(), is_equal_approx(o.grow_secs(), 300.0))
    check("默认山庄直接折钱（sell_mode auto）", o.auto_sell())
    check("默认不按真实月份（season_gate 关着）", not o.season_on() and o.kind_on("strawberry") and o.kind_on("loquat"))
    check("头一回进来地都是熟的（草莓 8 垄、枇杷 6 棵）", o.ripe_count("strawberry") == 8 and o.ripe_count("loquat") == 6)

    # 3. 【熟了不叠】挂多久回来都是一轮的量（01 9/20 定的底线）
    print("3 熟了不叠")
    age_all(o, 300.0 * 288.0)           # 挂了一整天（288 轮）
    check("挂一天：还是 14 块地熟了，不是 288 轮", o.ripe_count("strawberry") == 8 and o.ripe_count("loquat") == 6)
    var ripe_max := 0.0
    for p in o.plots:
        ripe_max = maxf(ripe_max, o.ripeness(p["id"]))
    check("长到头就封顶（最大 %.2f）" % ripe_max, is_equal_approx(ripe_max, 1.0))
    m.orchard_save.basket = {}
    o.farm["sell_mode"] = "manual"       # 先收进果篮，好数一共收了多少
    var got_s: int = o.harvest("strawberry")
    var got_l: int = o.harvest("loquat")
    check("挂一天一次收完 = %d 筐草莓 + %d 篮枇杷 = %d 金（一轮的量）" % [got_s, got_l, o.basket_coins()],
        got_s == 8 and got_l == 6 and o.basket_coins() == 40)
    check("没有加速成熟、立刻收获这类口子", not o.has_method("speed_up") and not o.has_method("instant_ripe") and not o.farm.has("speed_up"))
    m.orchard_save.basket = {}
    m.orchard_save.plots = {}

    # 4. 进果园，走到垄间收草莓（manual：进果篮）
    print("4 收草莓")
    m.nickname = "阿花"
    await m._enter_court()
    m.dialog.visible = false
    walk_to(m.court.spot_pos("to_plaza"))   # 10/4 新总图：迎宾院 → 喷泉广场 → 草坪
    walk_to(m.plaza.spot_pos("to_lawn"))
    walk_to(Vector2(768, 300))
    walk_to(l.spot_pos("to_orchard"))
    check("草坪北口到了果园 A，站在 A 南口里边 %s" % o.pos, m.state == "orchard" and o.pos == o.arrival_at("to_lawn"))
    var calls := []
    var real_cloud = m.cloud
    var spy := SpyCloud.new()
    spy.calls = calls
    m.cloud = spy
    walk_into(o, "strawberry", Vector2(1046, 796))
    check("垄间出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "收草莓（8 垄熟了）")
    var coins0: int = m.games_save.coins
    ui._on_act()
    tick(2)
    check("收了说「%s」" % m.said_raw, m.dialog.visible and m.said_raw == "收了 8 筐草莓 放进果篮")
    check("果篮里 8 筐草莓", m.orchard_save.basket_of("strawberry") == 8)
    check("第一次收草莓那句阿鱼的话还是【待补】：不弹、也不记弹过", CourtCopy.text("first_strawberry", CourtCopy.ORCHARD) == "【待补】"
        and CourtCopy.who("first_strawberry", CourtCopy.ORCHARD) == "阿鱼" and not m.orchard_save.firsts.has("strawberry"))
    check("垄上的草莓收光了（熟的 %d 块、光地 %d 块）" % [o.ripe_count("strawberry"), stage_count(o, "strawberry", 0)],
        o.ripe_count("strawberry") == 0 and stage_count(o, "strawberry", 0) == 8)
    check("按钮收了", not ui.act_btn.visible)
    check("还没卖，金币没动（%d 金）" % m.games_save.coins, m.games_save.coins == coins0)
    check("枇杷没跟着被收走（还熟着 %d 棵）" % o.ripe_count("loquat"), o.ripe_count("loquat") == 6)

    # 5. 长：一半变青果，到点才熟；人站着不动地也在长
    print("5 长")
    m.note.text = ""
    walk_into(o, "strawberry", Vector2(1046, 796))
    check("刚收完站过去：%s" % m.note.text, m.note.text == "草莓还有 5 分 0 秒 熟" and not ui.act_btn.visible)
    o.fake_now += 180.0                     # 长了六成
    o.refresh_fruit()
    check("六成：垄上是青果（青 %d 块、熟 %d 块）" % [stage_count(o, "strawberry", 1), o.ripe_count("strawberry")],
        stage_count(o, "strawberry", 1) == 8 and o.ripe_count("strawberry") == 0)
    m.note.text = ""
    walk_into(o, "strawberry", Vector2(1046, 796))
    check("青果的时候：%s" % m.note.text, m.note.text == "草莓还有 2 分 0 秒 熟" and not ui.act_btn.visible)
    o.fake_now += 130.0                     # 到点
    tick(40)                                # 人站着不动，地自己长（main 每帧叫 sync）
    check("到点了：8 垄又熟了", o.ripe_count("strawberry") == 8)
    walk_into(o, "strawberry", Vector2(1046, 796))
    check("按钮自己回来了「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "收草莓（8 垄熟了）")

    # 6. 人不在也长：离开果园、时间过去，回来该熟的熟了
    print("6 人不在也长")
    ui._on_act()                            # 先收掉，地清零
    tick(2)
    walk_to(o.spot_pos("to_lawn"))
    check("回到草坪", m.state == "lawn")
    o.fake_now += 300.0                     # 人在草坪上待了 5 分钟
    walk_to(l.spot_pos("to_orchard"))
    check("回果园，地在外面自己熟了（%d 垄）" % o.ripe_count("strawberry"), m.state == "orchard" and o.ripe_count("strawberry") == 8)

    # 7. 卖给山庄（manual：跑一趟收购处）
    print("7 卖")
    walk_into(o, "loquat", Vector2(386, 836))
    check("树下出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "收枇杷（6 棵熟了）")
    ui._on_act()
    tick(2)
    # 果篮会攒：第 4 步收的 8 筐、第 6 步收的 8 筐都还在，这次又添 6 篮枇杷
    check("果篮攒着：草莓 %d 筐、枇杷 %d 篮" % [m.orchard_save.basket_of("strawberry"), m.orchard_save.basket_of("loquat")],
        m.orchard_save.basket_of("strawberry") == 16 and m.orchard_save.basket_of("loquat") == 6)
    check("果篮值 %d 金（草莓 16×2 + 枇杷 6×4）" % o.basket_coins(), o.basket_coins() == 56)
    m.dialog.visible = false
    walk_into(o, "shop", Vector2(556, 1016))
    check("收购处出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "卖给山庄（56 金）")
    ui._on_act()
    tick(2)
    check("卖了说「%s」" % m.said_raw, m.dialog.visible and m.said_raw == "你的 草莓 16 筐 枇杷 6 篮 卖了 56 金")
    check("金币进了和小游戏同一个钱包（%d 金）" % m.games_save.coins, m.games_save.coins == coins0 + 56)
    check("果篮空了", m.orchard_save.basket_total() == 0)
    check("按钮收了", not ui.act_btn.visible)
    check("存金币走的是现成的 saveProfile，没新云函数（调了 %s）" % [calls], calls == ["saveProfile"])
    m.cloud = real_cloud
    spy.free()
    m.note.text = ""
    walk_into(o, "shop", Vector2(556, 1016))
    check("果篮空着再去收购处：%s，不出按钮" % m.note.text, m.note.text == "果篮是空的 先去收点果子" and not ui.act_btn.visible)

    # 8. 本机存着：关了游戏再开，地还是刚才那个进度
    print("8 存本机")
    var again = OrchardSave.new()
    again.local_path = SAVE_PATH
    again.load_local()
    var kept: bool = again.plots.size() == 14
    for p in o.plots:
        kept = kept and absf(again.picked_at(p["id"]) - m.orchard_save.picked_at(p["id"])) < 0.5
    check("14 块地的时刻都存下来了（存了 %d 块）" % again.plots.size(), kept)
    check("果篮也存下来了（空的）", again.basket_total() == 0)

    # 9. 默认那种卖法（auto）：收完山庄直接折钱，不用跑收购处
    print("9 auto 卖法")
    o.farm["sell_mode"] = "auto"
    age_all(o, 400.0)                       # 都熟了
    var coins1: int = m.games_save.coins
    m.dialog.visible = false
    walk_into(o, "strawberry", Vector2(1046, 796))
    ui._on_act()
    tick(2)
    check("收完山庄直接折钱、只说「%s」不写金（蓝图 3.6）" % m.said_raw, m.games_save.coins == coins1 + 16 and m.orchard_save.basket_total() == 0
        and m.said_raw == "收了 8 筐草莓" and not m.said_raw.contains("金"))
    m.note.text = ""
    walk_into(o, "shop", Vector2(556, 1016))
    check("这种卖法下走到收购处：%s" % m.note.text, m.note.text == "果子山庄直接收走了 不用跑这一趟" and not ui.act_btn.visible)

    # 9b. 第一次收枇杷弹阿鱼一句（蓝图 3.6，9/20 定）：照阿鱼写好了的样子测（不动文件）；只弹一次，记在本机
    print("9b 第一次收弹阿鱼一句")
    var pl: Dictionary = CourtCopy._lines(CourtCopy.ORCHARD)
    var keep_l: Dictionary = pl["first_loquat"].duplicate()
    pl["first_loquat"]["text"] = "测试：第一次收枇杷这句"
    age_all(o, 400.0)
    m.dialog.visible = false
    m.note.text = ""
    walk_into(o, "loquat", Vector2(386, 836))
    ui._on_act()
    tick(2)
    check("第一次收枇杷：对话框是阿鱼那句「%s」（%s）、收了几篮挪到顶部「%s」" % [m.said_raw, m.dialog_who.text, m.note.text],
        m.dialog.visible and m.said_raw == "测试：第一次收枇杷这句" and m.dialog_who.text == "阿鱼" and m.note.text == "收了 6 篮枇杷")
    var again2 = OrchardSave.new()
    again2.local_path = SAVE_PATH
    again2.load_local()
    check("弹过记在本机（%s）" % [again2.firsts], again2.firsts.get("loquat", false) == true and not again2.firsts.has("strawberry"))
    age_all(o, 400.0)
    m.dialog.visible = false
    walk_into(o, "loquat", Vector2(386, 836))
    ui._on_act()
    tick(2)
    check("第二回收枇杷不再弹：%s" % m.said_raw, m.said_raw == "收了 6 篮枇杷")
    m.orchard_save.firsts = {}
    m.orchard_save.load_local()
    check("关了再开（重读本机存档）也记得弹过", m.orchard_save.firsts.get("loquat", false) == true)
    pl["first_loquat"] = keep_l

    # 10. season_gate 打开：蓝图 3.6 那套老玩法还在
    print("10 季节开关")
    o.farm["season_gate"] = true
    o.fake_today = "2026-09-20"             # 两种都不在季节
    age_all(o, 400.0)
    check("季节关着的时候不长（熟 %d 块）" % (o.ripe_count("strawberry") + o.ripe_count("loquat")),
        o.ripe_count("strawberry") == 0 and o.ripe_count("loquat") == 0)
    m.note.text = ""
    walk_into(o, "strawberry", Vector2(1046, 796))
    check("出蓝图原话「%s」，不出按钮" % m.note.text, m.note.text == "还没到时候" and not ui.act_btn.visible)
    o.fake_today = "2026-12-08"             # 草莓的季节
    age_all(o, 400.0)
    check("到季节又长了（草莓 %d 垄熟、枇杷 %d 棵）" % [o.ripe_count("strawberry"), o.ripe_count("loquat")],
        o.ripe_count("strawberry") == 8 and o.ripe_count("loquat") == 0)
    o.farm["season_gate"] = false
    o.fake_today = ""

    # 10b. 手机时间往回拨（蓝图 3.6 异常处理）：不结算负数，从现在重算
    print("10b 时间往回拨")
    age_all(o, 100.0)
    o.fake_now -= 86400.0 * 30.0            # 手机时间退回一个月
    o.refresh_fruit()
    var back_ok := true
    for p in o.plots:
        var at: float = m.orchard_save.picked_at(p["id"])
        back_ok = back_ok and at <= o.now() and o.ripeness(p["id"]) >= 0.0 and o.ripeness(p["id"]) < 0.01
    check("往回拨一个月：地从现在重算，没有负数、也不用白等一个月", back_ok and o.ripe_count("strawberry") == 0)
    o.fake_now += 300.0
    o.refresh_fruit()
    check("往回拨以后照样 5 分钟熟（%d 垄）" % o.ripe_count("strawberry"), o.ripe_count("strawberry") == 8)

    # 11. 月份表还能换（蓝图 3.6 那两行标着待验证，改 json 不改代码）
    print("11 月份表")
    var cfg: Dictionary = o.seasons
    check("草莓 12～4 月、枇杷 4～6 月", Orchard.in_season("strawberry", "2026-12-08", cfg) and not Orchard.in_season("strawberry", "2026-09-20", cfg)
        and Orchard.in_season("loquat", "2026-05-12", cfg) and not Orchard.in_season("loquat", "2026-12-08", cfg))
    check("2026 年以前当无果", not Orchard.in_season("strawberry", "2025-12-08", cfg))
    var mine := {"min_year": 2020, "fruits": {"peach": {"months": [7, 8]}}}
    check("换一份月份表就按新的算", Orchard.in_season("peach", "2021-07-09", mine) and not Orchard.in_season("peach", "2021-09-09", mine))

    # 12. 还有多久，说成人话
    print("12 倒计时的说法")
    check("%s / %s / %s" % [Orchard.left_text(40.0), Orchard.left_text(130.0), Orchard.left_text(300.0)],
        Orchard.left_text(40.0) == "40 秒" and Orchard.left_text(130.0) == "2 分 10 秒" and Orchard.left_text(300.0) == "5 分 0 秒")

    # 13. 进出：草坪北口 ↔ 果园南口，不来回弹
    print("13 进出")
    walk_to(o.spot_pos("to_lawn"))
    check("A 南口回到草坪，站在北口里边 %s" % l.pos, m.state == "lawn" and l.pos == l.arrival_at("to_orchard"))
    tick(60)
    check("站着 60 帧不弹回果园", m.state == "lawn")
    walk_to(l.spot_pos("to_orchard"))
    check("又到果园 A，站在 A 南口里边", m.state == "orchard" and o.pos == o.arrival_at("to_lawn"))
    tick(60)
    check("站着 60 帧不弹回草坪", m.state == "orchard")

    # 14. 存档被改花了（01 9/20，03 提）：null、又套一层字典、字符串这几项直接丢掉，
    #     不留红字日志，兜底还是「这块地没收过」
    print("14 存档被改花了")
    var dirty_path := "user://test_orchard_dirty.json"
    var df := FileAccess.open(dirty_path, FileAccess.WRITE)
    df.store_string('{"plots":{"ridge_0":null,"ridge_1":{"a":1},"ridge_2":"坏的","ridge_3":123.5},"basket":{"strawberry":null,"loquat":2}}')
    df.close()
    var dirty = OrchardSave.new()
    dirty.local_path = dirty_path
    dirty.load_local()
    check("坏的那三项丢掉，只留下能算的一项（留了 %d 项）" % dirty.plots.size(), dirty.plots.size() == 1)
    check("坏的那块地兜底成「没收过」（%.0f）" % dirty.picked_at("ridge_0"), dirty.picked_at("ridge_0") < 0.0 and dirty.picked_at("ridge_1") < 0.0)
    check("能算的那项照常读出来（%.1f）" % dirty.picked_at("ridge_3"), is_equal_approx(dirty.picked_at("ridge_3"), 123.5))
    check("果篮同理：坏的丢掉（草莓 %d 枇杷 %d）" % [dirty.basket_of("strawberry"), dirty.basket_of("loquat")],
        dirty.basket_of("strawberry") == 0 and dirty.basket_of("loquat") == 2)
    DirAccess.remove_absolute(dirty_path)

    DirAccess.remove_absolute("user://test_orchard_games.json")
    DirAccess.remove_absolute("user://test_orchard_court.json")
    DirAccess.remove_absolute(SAVE_PATH)
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

## 只记下调了哪个云函数、不回话
class SpyCloud extends Node:
    var _in_wx := false   # 主界面按云桥是否在微信中设置顶部安全区
    var calls: Array
    func call_fn(name: String, _data: Dictionary, _cb: Callable, _timeout := 12.0) -> void:
        calls.append(name)
    func openid() -> String:
        return "fake_me"
