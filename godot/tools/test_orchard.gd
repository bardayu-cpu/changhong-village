extends SceneTree
## 验收：罗曼山庄果园（蓝图 3.6，灰盒，01 9/20 派任务 10）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 布局：三个交互点和蓝图一字不差；西边八条草莓垄、东边六棵枇杷树（两行三列）、中间小路、北边 y 0～200 不能走；人在垄间走得开。
## 季节（蓝图 3.6，月份表在 assets/orchard/seasons.json，可调）：草莓 12～4 月、枇杷 4～6 月；到季节才有果、才出「摘一颗」；
## 没到季节出「还没到时候」、不出按钮；日期早于 min_year（2026）按当季无果；两种都没到季节果园照样进得去。
## 摘：每天每种只能摘一颗，本机记；摘了只有一句话，没有奖励、不进背包、不调云函数；隔天又能摘
## 进出：草坪北口 ↔ 果园南口，到了站的点离出口至少 1 米、不来回弹
## 用法：Godot --headless --path . --script res://tools/test_orchard.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Orchard = preload("res://scripts/orchard.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0

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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    var o = m.orchard
    var l = m.lawn
    m.games_save.local_path = "user://test_orchard_games.json"
    m.court_save.local_path = "user://test_orchard_court.json"
    m.orchard_save.local_path = "user://test_orchard.json"
    m.orchard_save.picked = {}

    # 1. 布局对蓝图 3.6
    print("1 布局对蓝图 3.6")
    var want := {"strawberry": [400, 540, 60], "loquat": [1150, 500, 60], "to_lawn": [768, 880, 60]}
    var same: bool = o.points.size() == 3
    for id in want:
        same = same and o.points.has(id) and o.points[id]["pos"] == Vector2(want[id][0], want[id][1]) and is_equal_approx(float(o.points[id]["r"]), float(want[id][2]))
    check("三个交互点和蓝图一字不差", same)
    var ridges: Array = []
    var trees: Array = []
    for it in o.cfg["items"]:
        if str(it["id"]).begins_with("ridge_"):
            ridges.append(it)
        elif str(it["id"]).begins_with("loquat_"):
            trees.append(it)
    var ridge_ok := ridges.size() == 8
    for r in ridges:
        var rect: Array = r["rect"]
        ridge_ok = ridge_ok and float(rect[0]) >= 100.0 and float(rect[2]) <= 700.0 and float(rect[1]) >= 250.0 and float(rect[3]) <= 800.0
    check("八条草莓垄，都在 x 100～700、y 250～800 里", ridge_ok)
    var xs := {}
    var ys := {}
    for t in trees:
        xs[t["x"]] = true
        ys[t["y"]] = true
    check("六棵枇杷树，两行三列（行 %d 列 %d），都在 x 850～1450" % [ys.size(), xs.size()],
        trees.size() == 6 and ys.size() == 2 and xs.size() == 3 and xs.keys().min() >= 850 and xs.keys().max() <= 1450)
    var gap_walk := 0
    for y in [336, 404, 472, 540, 608, 676, 744]:
        if o._free(Vector2(400, y)):
            gap_walk += 1
    check("垄间走得开（七条空道能站 %d 条）" % gap_walk, gap_walk == 7)
    var on_ridge := 0
    for r in ridges:
        if o._free(Vector2(400, (float(r["rect"][1]) + float(r["rect"][3])) * 0.5)):
            on_ridge += 1
    check("垄上踩不进去（踩进 %d 条）" % on_ridge, on_ridge == 0)
    check("中间小路南北都能走", o._free(Vector2(768, 300)) and o._free(Vector2(768, 700)) and o._free(Vector2(768, 860)))
    check("北边田埂、远处的田不能走", not o._free(Vector2(768, 150)) and not o._free(Vector2(300, 100)))
    check("到了站在 %s 离南口 %.0f 像素（至少 48），能站" % [m.ORCHARD_FROM_LAWN, m.ORCHARD_FROM_LAWN.distance_to(o.points["to_lawn"]["pos"])],
        o.SPAWN == m.ORCHARD_FROM_LAWN and m.ORCHARD_FROM_LAWN.distance_to(o.points["to_lawn"]["pos"]) >= 48.0 and o._free(m.ORCHARD_FROM_LAWN))
    check("回草坪站的点 %s 离北口 %.0f 像素（至少 48）" % [m.LAWN_FROM_ORCHARD, m.LAWN_FROM_ORCHARD.distance_to(l.points["to_orchard"]["pos"])],
        m.LAWN_FROM_ORCHARD.distance_to(l.points["to_orchard"]["pos"]) >= 48.0 and l._free(m.LAWN_FROM_ORCHARD))
    for id in o.points:
        var pt: Vector2 = o.points[id]["pos"]
        var path: Array = o.find_path(o.SPAWN, pt)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else o.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(pt), o.points[id]["r"]], end.distance_to(pt) < float(o.points[id]["r"]))

    # 2. 季节：月份表可调，早于 2026 年按当季无果
    print("2 季节")
    var cfg: Dictionary = o.seasons
    check("草莓 12～4 月", Orchard.in_season("strawberry", "2026-12-08", cfg) and Orchard.in_season("strawberry", "2027-01-15", cfg)
        and Orchard.in_season("strawberry", "2026-04-30", cfg) and not Orchard.in_season("strawberry", "2026-05-01", cfg)
        and not Orchard.in_season("strawberry", "2026-09-20", cfg))
    check("枇杷 4～6 月", Orchard.in_season("loquat", "2026-04-01", cfg) and Orchard.in_season("loquat", "2026-06-30", cfg)
        and not Orchard.in_season("loquat", "2026-07-01", cfg) and not Orchard.in_season("loquat", "2026-12-08", cfg))
    check("2026 年以前按当季无果", not Orchard.in_season("strawberry", "2025-12-08", cfg) and not Orchard.in_season("loquat", "2025-05-01", cfg))
    check("日期不成样子也当没果", not Orchard.in_season("strawberry", "", cfg) and not Orchard.in_season("strawberry", "坏日期", cfg))
    var mine := {"min_year": 2020, "fruits": {"peach": {"months": [7, 8]}}}
    check("月份表换一份就按新的算", Orchard.in_season("peach", "2021-07-09", mine) and not Orchard.in_season("peach", "2021-09-09", mine))

    # 3. 草坪北口 ↔ 果园南口
    print("3 进出")
    m.nickname = "阿花"
    await m._enter_court()
    m.dialog.visible = false
    walk_to(m.court.spot_pos("to_lawn"))
    check("先到草坪", m.state == "lawn")
    walk_to(Vector2(768, 300))
    walk_to(l.spot_pos("to_orchard"))
    check("北口到了果园 state=%s" % m.state, m.state == "orchard" and m.cv == o and o.visible and not l.visible)
    check("站在南口边 (768,820) %s" % o.pos, o.pos == m.ORCHARD_FROM_LAWN)
    tick(60)
    check("站着 60 帧不弹回草坪", m.state == "orchard")
    walk_to(o.spot_pos("to_lawn"))
    check("南口回到草坪，站在 (768,220) %s" % l.pos, m.state == "lawn" and l.pos == m.LAWN_FROM_ORCHARD)
    tick(60)
    check("站着 60 帧不弹回果园", m.state == "lawn")
    walk_to(l.spot_pos("to_orchard"))
    check("又到果园", m.state == "orchard")

    # 4. 十二月：草莓有、枇杷没有
    print("4 十二月")
    var ui = m.orchard_ui
    o.fake_today = "2026-12-08"
    m.orchard_save.picked = {}
    o.refresh_fruit()
    var straw_on := 0
    for n in o.fruit_nodes["strawberry"]:
        if (n as Node2D).visible:
            straw_on += 1
    var loquat_on := 0
    for n in o.fruit_nodes["loquat"]:
        if (n as Node2D).visible:
            loquat_on += 1
    check("垄上有草莓（%d 颗）、树上没枇杷（%d 颗）" % [straw_on, loquat_on], straw_on > 0 and loquat_on == 0)
    walk_into(o, "loquat", Vector2(1150, 580))
    check("枇杷树下：%s，不出按钮" % m.note.text, m.note.text == "还没到时候" and not ui.act_btn.visible)
    walk_into(o, "strawberry", Vector2(490, 540))
    check("草莓垄间出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "摘一颗")

    # 5. 摘一颗：一句话、没有奖励、不调云函数、垄上少一颗；今天不能再摘；隔天又能摘
    print("5 摘一颗")
    var coins0: int = m.games_save.coins
    var calls := []
    var real_cloud = m.cloud
    var spy := SpyCloud.new()
    spy.calls = calls
    m.cloud = spy
    ui._on_act()
    tick(2)
    m.cloud = real_cloud
    spy.free()
    check("%s：%s" % [m.dialog_who.text, m.dialog_text.text], m.dialog.visible and m.dialog_text.text == "刚红的 甜" and m.dialog_who.text == "阿鱼")
    check("一次云函数都没调 %s" % [calls], calls.is_empty())
    check("金币没变（%d）" % m.games_save.coins, m.games_save.coins == coins0)
    check("本机记了今天摘过", m.orchard_save.picked_on("strawberry") == "2026-12-08" and o.picked_today("strawberry"))
    check("按钮收了", not ui.act_btn.visible)
    var straw_now := 0
    for n in o.fruit_nodes["strawberry"]:
        if (n as Node2D).visible:
            straw_now += 1
    check("垄上少一颗（%d → %d）" % [straw_on, straw_now], straw_now == straw_on - 1)
    m.note.text = ""
    walk_into(o, "strawberry", Vector2(490, 540))
    check("今天再去：%s，不出按钮" % m.note.text, m.note.text == "今天摘过一颗了" and not ui.act_btn.visible)
    o.fake_today = "2026-12-09"
    o.refresh_fruit()
    walk_into(o, "strawberry", Vector2(490, 540))
    check("隔天又能摘：出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "摘一颗")

    # 6. 五月：枇杷有、草莓没有；摘枇杷说另一句
    print("6 五月")
    o.fake_today = "2026-05-12"
    m.orchard_save.picked = {}
    o.refresh_fruit()
    m.dialog.visible = false
    walk_into(o, "strawberry", Vector2(490, 540))
    check("草莓垄间：%s，不出按钮" % m.note.text, m.note.text == "还没到时候" and not ui.act_btn.visible)
    walk_into(o, "loquat", Vector2(1150, 580))
    check("枇杷树下出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "摘一颗")
    ui._on_act()
    tick(2)
    check("%s：%s" % [m.dialog_who.text, m.dialog_text.text], m.dialog.visible and m.dialog_text.text == "枇杷刚黄 汁多")
    check("枇杷也记本机", m.orchard_save.picked_on("loquat") == "2026-05-12")

    # 7. 九月（今天）：两种都没到季节，果园照样进得去、走得动
    print("7 九月")
    o.fake_today = "2026-09-20"
    m.orchard_save.picked = {}
    o.refresh_fruit()
    var any_on := 0
    for kind in ["strawberry", "loquat"]:
        for n in o.fruit_nodes[kind]:
            if (n as Node2D).visible:
                any_on += 1
    check("两种都没果（%d 颗）" % any_on, any_on == 0)
    walk_into(o, "strawberry", Vector2(490, 540))
    check("草莓：%s" % m.note.text, m.note.text == "还没到时候" and not ui.act_btn.visible)
    walk_into(o, "loquat", Vector2(1150, 580))
    check("枇杷：%s" % m.note.text, m.note.text == "还没到时候" and not ui.act_btn.visible)
    walk_to(o.spot_pos("to_lawn"))
    check("照样走得出去（回草坪）", m.state == "lawn")

    DirAccess.remove_absolute("user://test_orchard_games.json")
    DirAccess.remove_absolute("user://test_orchard_court.json")
    DirAccess.remove_absolute("user://test_orchard.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

## 只记下调了哪个云函数、不回话
class SpyCloud extends Node:
    var calls: Array
    func call_fn(name: String, _data: Dictionary, _cb: Callable, _timeout := 12.0) -> void:
        calls.append(name)
    func openid() -> String:
        return "fake_me"
