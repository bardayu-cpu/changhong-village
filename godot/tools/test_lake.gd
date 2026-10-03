extends SceneTree
## 验收：罗曼山庄湖边（蓝图 3.5，灰盒，01 9/20 派任务 9）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 10/3 阿鱼改成一条往西延伸的长湖岸（tools/layout_court/make_lake_long.py；东头照效果图 2、西头照翻转的效果图 1）：画布 3072×1280，
## 湖面、对岸不能走；东头曲桥三折通到湖心亭（6 米，乐手四位），湖岸石板小路连着东西两头，西头伸进水里一块小半岛；
## 曲桥上摇杆往两边推不下水（边缘挡住，蓝图 3.5 异常处理）；柳树、长凳、亭子都在。南墙两道月亮门：东头回迎宾院、西头去停车场。
## 亭子：走进去自动出一句、走出去收；阿鱼写好之前（「【待补】」）不出（01 E 10/3）（《世界观》4.2 记忆点只有阿鱼能写）。
## 长凳：走到旁边出「坐下」，点一下坐（面朝湖、换坐姿、镜头不变焦），再点起来；自己推摇杆也会站起来，按钮跟着变回「坐下」。
## 进出：迎宾院西小径 ↔ 湖边东头月亮门、停车场白墙月亮门 ↔ 湖边西头月亮门，到了站的点离出口至少 1 米、不来回弹
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
    # 后厅、草坪、湖边、果园开场不搭、第一次进去才搭（main.ensure_canvas，02 10/3）：这里要直接看它们，先搭好
    for cn in ["backhall", "lawn", "lake", "orchard"]:
        m.ensure_canvas(cn)
    await process_frame
    var k = m.lake
    var c = m.court
    m.games_save.local_path = "user://test_lake_games.json"
    m.court_save.local_path = "user://test_lake_court.json"

    # 1. 布局（10/3 长湖岸）
    print("1 布局（长湖岸）")
    check("画布拉宽成 %s" % [k.cfg["size"]], int(k.cfg["size"][0]) == 3072 and int(k.cfg["size"][1]) == 1280)
    var ids: Array = k.points.keys()
    ids.sort()
    check("四个交互点：%s" % [ids], ids == ["bench", "pavilion", "to_entrance", "to_parking"])
    check("东头月亮门在东半、西头月亮门在西半、亭子在东头湖里", k.points["to_entrance"]["pos"].x > 1536.0 and k.points["to_parking"]["pos"].x < 1536.0
        and k.points["pavilion"]["pos"].x > 1536.0 and k.points["pavilion"]["pos"].y < 784.0)
    var water := true
    for p in [Vector2(300, 556), Vector2(1200, 456), Vector2(2304, 300), Vector2(2400, 740), Vector2(2120, 760), Vector2(1500, 700),
            Vector2(2900, 600), Vector2(768, 120), Vector2(200, 60)]:   # 最后两个是顶上那条对岸风景带
        water = water and not k._free(p)
    check("湖面、曲桥两边、对岸都不能走", water)
    var walkable := true
    for p in [Vector2(2304, 740), Vector2(2210, 684), Vector2(2208, 600), Vector2(2304, 460), Vector2(530, 560), Vector2(532, 760),
            Vector2(1500, 820), Vector2(2304, 1000), Vector2(1000, 1100), Vector2(200, 820), Vector2(2950, 820)]:
        walkable = walkable and k._free(p)
    check("曲桥、湖心亭、半岛、湖岸小路、园子都能走", walkable)
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
    check("站在东头月亮门里边 %s，朝向没变 %s" % [k.pos, k.face], k.pos == m.LAKE_FROM_COURT and k.face == "left")
    tick(60)
    check("站着 60 帧不弹回迎宾院", m.state == "lake")
    walk_to(k.spot_pos("to_entrance"))
    check("东头月亮门回到迎宾院，站在 (100,520) %s" % c.pos, m.state == "court" and c.pos == m.COURT_FROM_LAKE)
    tick(60)
    check("站着 60 帧不弹回湖边", m.state == "court")
    walk_to(c.spot_pos("to_lake"))
    check("又到湖边", m.state == "lake")

    # 3. 曲桥上摇杆往两边推：掉不下去（蓝图 3.5 异常处理；10/3 起栈道换成东头三折曲桥）
    print("3 曲桥推不下水")
    var off := 0
    for start in [Vector2(2304, 740), Vector2(2220, 684), Vector2(2208, 610)]:
        for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0.9, -0.4), Vector2(-0.9, -0.4)]:
            k.reset_to(start)
            k.stick = d
            for i in 90:
                tick(1)
                # 湖岸北边（y 小于 790）只有曲桥和湖心亭能站：人只要在北边，就得在那一片里（x 2160～2448），而且脚下永远是能站的格子
                if not k._free(k.pos) or (k.pos.y < 790.0 and (k.pos.x < 2150.0 or k.pos.x > 2460.0)):
                    off += 1
                    break
    k.stick = Vector2.ZERO
    check("曲桥三段各往两边、斜着往上推 1.5 秒，一次也没下水（出界 %d 次，停在 %s）" % [off, k.pos], off == 0 and k._free(k.pos))

    # 4. 亭子：阿鱼写好之前（【待补】）走进去不出话（01 E 10/3：开发字样不给玩家看）；写好了走进去自动出一句，走出去收，再进去又出
    print("4 亭子")
    m.dialog.visible = false
    check("话在 lines.json 里还是【待补】", CourtCopy.text("pavilion", CourtCopy.LAKE) == "【待补】")
    walk_to(k.spot_pos("pavilion"))
    check("还是【待补】：走进亭子不出话", k.in_spot("pavilion") and not m.dialog.visible)
    walk_to(Vector2(2304, 760))
    var pl: Dictionary = CourtCopy._lines(CourtCopy.LAKE)
    var keep: Dictionary = pl["pavilion"].duplicate()
    pl["pavilion"]["text"] = "测试：亭子这句"   # 照阿鱼写好了的样子测（不动文件）
    walk_to(k.spot_pos("pavilion"))
    check("%s：%s" % [m.dialog_who.text, m.dialog_text.text], m.dialog.visible and m.dialog_text.text == "测试：亭子这句" and m.dialog_who.text == "阿鱼")
    walk_to(Vector2(2304, 760))
    check("走出亭子，那句收了", not m.dialog.visible and not k.in_spot("pavilion"))
    walk_to(k.spot_pos("pavilion"))
    check("再走进去又出", m.dialog.visible and m.dialog_text.text == "测试：亭子这句")
    pl["pavilion"] = keep
    walk_to(Vector2(2304, 900))

    # 5. 长凳：走到旁边出「坐下」，点一下坐（面朝湖、坐姿、镜头不变焦），再点起来
    print("5 长凳")
    var ui = m.lake_ui
    var zoom0: Vector2 = k.cam.zoom
    walk_to(k.spot_pos("bench") + Vector2(0, 80), 30.0)
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

    # 8. 西头月亮门 ↔ 停车场（10/3 长湖岸）：到了站的点离门至少 1 米、不来回弹
    print("8 西头月亮门 ↔ 停车场")
    m.ensure_canvas("parking")
    var pk = m.parking
    check("西头进来站的点 %s 离月亮门 %.0f（至少 48），能站" % [k.FROM_PARKING, k.FROM_PARKING.distance_to(k.points["to_parking"]["pos"])],
        k.FROM_PARKING.distance_to(k.points["to_parking"]["pos"]) >= 48.0 and k._free(k.FROM_PARKING))
    k.reset_to(k.FROM_PARKING + Vector2(0, -120))
    walk_to(k.spot_pos("to_parking"), 30.0)
    check("西头月亮门出去到了停车场（%s），站在白墙门洞外边 %s" % [m.state, pk.pos], m.state == "parking" and pk.pos == pk.FROM_LAKE)
    tick(60)
    check("站着 60 帧不弹回湖边", m.state == "parking")
    walk_to(pk.spot_pos("to_lake"))
    check("停车场白墙月亮门进来，站在西头门里边 %s" % k.pos, m.state == "lake" and k.pos == k.FROM_PARKING)
    tick(60)
    check("站着 60 帧不弹回停车场", m.state == "lake")
    var east: Array = k.find_path(k.FROM_PARKING, k.points["to_entrance"]["pos"])
    check("西头顺着湖岸走得到东头月亮门（整条湖岸通）", not east.is_empty() and (east[east.size() - 1] as Vector2).distance_to(k.points["to_entrance"]["pos"]) <= 36.0)

    DirAccess.remove_absolute("user://test_lake_games.json")
    DirAccess.remove_absolute("user://test_lake_court.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
