extends SceneTree
## 验收：罗曼山庄湖边（蓝图 3.5，灰盒，01 9/20 派任务 9）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 布局：三个交互点和蓝图一字不差；湖面（北半 y 0～520）不能走，栈道 x 720～816、y 300～560 和亭子（4 米见方，中心 768,300）能走，
## 南半 y 540～900 能走；栈道上摇杆往两边推不下水（边缘挡住，蓝图 3.5 异常处理）；柳树、长凳都在。
## 亭子：走进去自动出一句、走出去收，阿鱼写好之前是「【待补】」（《世界观》4.2 记忆点只有阿鱼能写）。
## 长凳：走到旁边出「坐下」，点一下坐（面朝湖、换坐姿、镜头不变焦），再点起来；自己推摇杆也会站起来，按钮跟着变回「坐下」。
## 进出：迎宾院西小径 ↔ 湖边东口，到了站的点离出口至少 1 米、不来回弹
## 用法：Godot --headless --path . --script res://tools/test_lake.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    var k = m.lake
    var c = m.court
    m.games_save.local_path = "user://test_lake_games.json"
    m.court_save.local_path = "user://test_lake_court.json"

    # 1. 布局对蓝图 3.5
    print("1 布局对蓝图 3.5")
    var want := {"pavilion": [768, 340, 60], "bench": [400, 720, 50], "to_entrance": [1500, 700, 50]}
    var same: bool = k.points.size() == 3
    for id in want:
        same = same and k.points.has(id) and k.points[id]["pos"] == Vector2(want[id][0], want[id][1]) and is_equal_approx(float(k.points[id]["r"]), float(want[id][2]))
    check("三个交互点和蓝图一字不差", same)
    var water := true
    for p in [Vector2(300, 300), Vector2(1200, 200), Vector2(768, 120), Vector2(690, 450), Vector2(850, 450), Vector2(400, 520)]:
        water = water and not k._free(p)
    check("湖面、栈道两边都不能走", water)
    var walkable := true
    for p in [Vector2(768, 450), Vector2(726, 540), Vector2(810, 320), Vector2(768, 340), Vector2(700, 300), Vector2(830, 300),
            Vector2(200, 700), Vector2(1400, 800), Vector2(768, 860)]:
        walkable = walkable and k._free(p)
    check("栈道、亭子、南半都能走", walkable)
    check("到了站的点 %s 离东口 %.0f 像素（至少 48），能站" % [m.LAKE_FROM_COURT, m.LAKE_FROM_COURT.distance_to(k.points["to_entrance"]["pos"])],
        k.SPAWN == m.LAKE_FROM_COURT and m.LAKE_FROM_COURT.distance_to(k.points["to_entrance"]["pos"]) >= 48.0 and k._free(m.LAKE_FROM_COURT))
    check("回迎宾院站的点 %s 离西小径 %.0f 像素（至少 48）" % [m.COURT_FROM_LAKE, m.COURT_FROM_LAKE.distance_to(c.points["to_lake"]["pos"])],
        m.COURT_FROM_LAKE.distance_to(c.points["to_lake"]["pos"]) >= 48.0 and c._free(m.COURT_FROM_LAKE))
    for id in k.points:
        var pt: Vector2 = k.points[id]["pos"]
        var path: Array = k.find_path(k.SPAWN, pt)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else k.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(pt), k.points[id]["r"]], end.distance_to(pt) < float(k.points[id]["r"]))
    var willows := 0
    for n in k.world.get_children():
        if str(n.name).begins_with("willow_"):
            willows += 1
    check("几棵柳树（%d）、长凳、亭子都在" % willows, willows >= 4 and k.world.has_node("bench_seat") and k.world.has_node("bench_back")
        and k.world.has_node("pavilion_roof") and k.world.has_node("post_nw"))

    # 2. 迎宾院西小径 ↔ 湖边东口：站的点、朝向、不来回弹
    print("2 进出")
    m.nickname = "阿花"
    await m._enter_court()
    m.dialog.visible = false
    walk_to(c.spot_pos("to_lake") + Vector2(150, 0))
    walk_to(c.spot_pos("to_lake"))
    check("西小径到了湖边 state=%s" % m.state, m.state == "lake" and m.cv == k and k.visible and not c.visible)
    check("站在东口边 (1440,700) %s，朝向没变 %s" % [k.pos, k.face], k.pos == m.LAKE_FROM_COURT and k.face == "left")
    tick(60)
    check("站着 60 帧不弹回迎宾院", m.state == "lake")
    walk_to(k.spot_pos("to_entrance"))
    check("东口回到迎宾院，站在 (100,520) %s" % c.pos, m.state == "court" and c.pos == m.COURT_FROM_LAKE)
    tick(60)
    check("站着 60 帧不弹回湖边", m.state == "court")
    walk_to(c.spot_pos("to_lake"))
    check("又到湖边", m.state == "lake")

    # 3. 栈道上摇杆往两边推：掉不下去（蓝图 3.5 异常处理）
    print("3 栈道推不下水")
    k.reset_to(Vector2(768, 450))
    var off := 0
    for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0.9, -0.4), Vector2(-0.9, -0.4)]:
        k.reset_to(Vector2(768, 450))
        k.stick = d
        for i in 90:
            tick(1)
            # 北半（y 小于 534）只有栈道和亭子能站：人只要在北半，就得在栈道或亭子的范围里，而且脚下永远是能站的格子
            var in_deck: bool = k.pos.x >= 714.0 and k.pos.x <= 822.0
            var in_pav: bool = k.pos.y <= 402.0 and k.pos.x >= 666.0 and k.pos.x <= 870.0
            if not k._free(k.pos) or (k.pos.y < 534.0 and not (in_deck or in_pav)):
                off += 1
                break
    k.stick = Vector2.ZERO
    check("往两边、斜着往上各推 1.5 秒，一次也没下水（出界 %d 次，停在 %s）" % [off, k.pos], off == 0 and k._free(k.pos))

    # 4. 亭子：走进去自动出一句（阿鱼写好之前是【待补】），走出去收，再进去又出
    print("4 亭子")
    m.dialog.visible = false
    walk_to(k.spot_pos("pavilion"))
    check("%s：%s" % [m.dialog_who.text, m.dialog_text.text], m.dialog.visible and m.dialog_text.text == "【待补】" and m.dialog_who.text == "阿鱼")
    check("话在 lines.json 里也是【待补】", CourtCopy.text("pavilion", CourtCopy.LAKE) == "【待补】")
    walk_to(Vector2(768, 520))
    check("走出亭子，那句收了", not m.dialog.visible and not k.in_spot("pavilion"))
    walk_to(k.spot_pos("pavilion"))
    check("再走进去又出", m.dialog.visible and m.dialog_text.text == "【待补】")
    walk_to(Vector2(768, 620))

    # 5. 长凳：走到旁边出「坐下」，点一下坐（面朝湖、坐姿、镜头不变焦），再点起来
    print("5 长凳")
    var ui = m.lake_ui
    var zoom0: Vector2 = k.cam.zoom
    walk_to(Vector2(400, 780))
    walk_to(k.spot_pos("bench"))
    check("走到长凳旁出「%s」" % ui.act_btn.text, ui.act_btn.visible and ui.act_btn.text == "坐下")
    check("还没坐", not k.seated)
    ui._on_act()
    tick(40)
    check("坐下了：位置 %s 朝向 %s" % [k.pos, k.face], k.seated and k.pos == k.BENCH_SEAT and k.face == "up")
    check("按钮变「%s」" % ui.act_btn.text, ui.act_btn.text == "起来")
    check("镜头没变焦（%s）" % k.cam.zoom, k.cam.zoom == zoom0)
    ui._on_act()
    tick(5)
    check("起来了，站在凳子南边 %s" % k.pos, not k.seated and k.pos == k.BENCH_STAND)
    check("按钮变回「%s」" % ui.act_btn.text, ui.act_btn.text == "坐下")

    # 6. 坐着推摇杆：自己站起来，按钮跟着变回「坐下」
    print("6 坐着推摇杆")
    ui._on_act()
    tick(40)
    check("又坐下了", k.seated)
    k.stick = Vector2(0, 1)
    tick(10)
    k.stick = Vector2.ZERO
    tick(2)
    check("推一下摇杆就站起来", not k.seated)
    check("按钮跟着变回「%s」" % ui.act_btn.text, ui.act_btn.text == "坐下")

    # 7. 坐着出湖边：回来是站着的，按钮也收了
    print("7 坐着离开")
    walk_to(k.spot_pos("bench"))
    ui._on_act()
    tick(40)
    check("坐下了", k.seated)
    m._switch_canvas("court")
    check("回到迎宾院，按钮收了", m.state == "court" and not ui.act_btn.visible)
    walk_to(c.spot_pos("to_lake"))
    check("再回湖边是站着的", m.state == "lake" and not k.seated)

    DirAccess.remove_absolute("user://test_lake_games.json")
    DirAccess.remove_absolute("user://test_lake_court.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
