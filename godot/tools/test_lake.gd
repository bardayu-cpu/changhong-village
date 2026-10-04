extends SceneTree
## 验收：罗曼山庄湖边（蓝图 3.5，灰盒，01 9/20 派任务 9）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 10/3 阿鱼改成一条往西延伸的长湖岸（tools/layout_court/make_lake_long.py；东头照效果图 2、西头照翻转的效果图 1）：画布 3072×1280，
## 湖面、对岸不能走；东头曲桥三折通到湖心亭（6 米，乐手四位），湖岸石板小路连着东西两头，西头伸进水里一块小半岛；
## 曲桥上摇杆往两边推不下水（边缘挡住，蓝图 3.5 异常处理）；柳树、长凳、亭子都在。南墙两道月亮门（10/4 连图起东头那道只通南墙外，西头那道去后花园）。
## 亭子：走进去自动出一句、走出去收；阿鱼写好之前（「【待补】」）不出（01 E 10/3）（《世界观》4.2 记忆点只有阿鱼能写）。
## 长凳：走到旁边出「坐下」，点一下坐（面朝湖、换坐姿、镜头不变焦），再点起来；自己推摇杆也会站起来，按钮跟着变回「坐下」。
## 进出（10/4 连图）：果园 A 西口 ↔ 湖边东头尽头、后花园北口 ↔ 湖边西头月亮门，到了站的点离出口至少 1 米、不来回弹
## 10/4 东半边（x ≥ 1536）换成代码画的像素成品（tools/pixel_art/lake_east.py）：曲桥改成一折往东北、再折回亭子前沿；
## 亭子顶不透明，人只走亭子前沿那条（y 636～652）；南墙挪到 y 1040；东半边的灰盒不画、只留挡人占地（on_art）
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
    # 10/4 连图（02 E 改）：湖边改从后花园、果园进，不再通迎宾院、停车场；10/4 西半边接图：多了码头、半岛亭子、西边长凳、湖尽头小石台
    check("八个交互点：%s" % [ids], ids == ["bench", "bench_w", "dock", "lake_end", "pavilion", "pavilion_w", "to_garden", "to_orchard"])
    # 南墙两道月亮门对称：西头 x 768 去果园 A、东头 x 2304 去后花园
    check("西头月亮门（x 768）去果园、东头月亮门（x 2304）去后花园、亭子在东头湖里", k.points["to_orchard"]["pos"] == Vector2(768, 1066) and k.points["to_garden"]["pos"].x > 1536.0
        and k.points["pavilion"]["pos"].x > 1536.0 and k.points["pavilion"]["pos"].y < 784.0)
    var water := true
    for p in [Vector2(300, 556), Vector2(1200, 456), Vector2(2304, 300), Vector2(2400, 740), Vector2(2120, 760), Vector2(1500, 700),
            Vector2(2900, 600), Vector2(2200, 700), Vector2(2304, 560), Vector2(2500, 760), Vector2(768, 120), Vector2(200, 60)]:   # 最后两个是顶上那条对岸风景带
        water = water and not k._free(p)
    check("湖面、曲桥两边、对岸都不能走", water)
    var walkable := true
    for p in [Vector2(2304, 780), Vector2(2400, 712), Vector2(2333, 655), Vector2(2280, 644), Vector2(556, 597), Vector2(908, 618),
            Vector2(1500, 820), Vector2(1536, 900), Vector2(1600, 838), Vector2(2304, 1000), Vector2(768, 999), Vector2(62, 500)]:   # 西半边：半岛亭子前沿、码头船夫跟前、西门里边、湖尽头小石台
        if not k._free(p):
            walkable = false
            print("    走不了 ", p)
    check("曲桥、亭子前沿、半岛、湖岸小路（东西两半接得上）、园子都能走", walkable)
    check("南墙挪到 y 1040，墙外 10/4 起也能走（看着是草地、石板路）（西 %s、东 %s）" % [k._free(Vector2(1000, 1150)), k._free(Vector2(2304, 1150))],
        k._free(Vector2(1000, 1150)) and k._free(Vector2(2304, 1150)))
    for pr in [["orchard", "to_orchard"], ["garden", "to_garden"]]:
        var at: Vector2 = k.arrival_from(pr[0])
        var gap: float = at.distance_to(k.points[pr[1]]["pos"])
        check("从%s过来站的点 %s 离口 %.0f 像素（至少 48），能站" % [pr[0], at, gap], gap >= 48.0 and k._free(at))
    for id in k.points:
        var pt: Vector2 = k.points[id]["pos"]
        var path: Array = k.find_path(k.SPAWN, pt)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else k.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(pt), k.points[id]["r"]], end.distance_to(pt) < float(k.points[id]["r"]))
    var wpx := 0
    for n in k.world.get_children():
        if str(n.name).begins_with("px_w_"):
            wpx += 1
    check("西半边像素成品铺上了（底图 + 立着的 %d 张）" % wpx, wpx == 137 and k.find_child("px_background_lake_west", true, false) != null)
    var px := true
    for id in ["px_wall_gate", "px_pavilion_front", "px_pavilion_back", "px_bench", "px_willow_1", "px_willow_2", "px_banyan_1", "px_boat"]:
        px = px and k.world.has_node(id)
    check("东半边像素成品铺上了（底图 + 墙、亭子、长凳、树、船）", px and k.find_child("px_background_lake_east", true, false) != null)
    var gray := 0
    for id in ["wall_s_w", "wall_s_e", "moongate_e", "pav_post_0", "bench_seat", "lantern_1", "willow_1"]:
        if k.world.has_node(id):
            gray += 1
    check("东半边不再画灰盒（剩 %d 件）" % gray, gray == 0)

    # 2. 果园（A 西口）↔ 湖边东头尽头：站的点、不来回弹（10/4 连图，02 E 改；原来是迎宾院西小径 ↔ 东头月亮门）
    print("2 进出")
    m.nickname = "阿花"
    await m._enter_court()
    m.dialog.visible = false
    m.ensure_canvas("orchard")
    var o = m.orchard
    m._show_canvas("orchard")
    m._goto("orchard")
    o.walking_enabled = true
    o.reset_to(o.arrival_at("to_lake"))
    walk_to(o.spot_pos("to_lake"))
    check("果园西口到了湖边 state=%s" % m.state, m.state == "lake" and m.cv == k and k.visible and not o.visible)
    check("站在东头尽头那个口里边 %s" % k.pos, k.pos == k.arrival_from("orchard"))
    tick(60)
    check("站着 60 帧不弹回果园", m.state == "lake")
    walk_to(k.spot_pos("to_orchard"))
    check("东头尽头回到果园，站在西口里边 %s" % o.pos, m.state == "orchard" and o.pos == o.arrival_from("lake"))
    tick(60)
    check("站着 60 帧不弹回湖边", m.state == "orchard")
    walk_to(o.spot_pos("to_lake"))
    check("又到湖边", m.state == "lake")

    # 3. 曲桥上摇杆往两边推：掉不下去（蓝图 3.5 异常处理；10/3 起栈道换成东头三折曲桥）
    print("3 曲桥推不下水")
    var off := 0
    for start in [Vector2(2304, 780), Vector2(2400, 712), Vector2(2333, 655)]:
        for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0.9, -0.4), Vector2(-0.9, -0.4)]:
            k.reset_to(start)
            k.stick = d
            for i in 90:
                tick(1)
                # 湖岸北边（y 小于 790）只有曲桥和亭子前沿能站：人只要在北边，就得在那一片里（x 2230～2480），而且脚下永远是能站的格子
                if not k._free(k.pos) or (k.pos.y < 790.0 and (k.pos.x < 2230.0 or k.pos.x > 2480.0)):
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
    m._switch_canvas("lake")
    check("再回湖边是站着的", m.state == "lake" and not k.seated)

    # 8. 西头月亮门 ↔ 后花园（10/4 连图，02 E 改；原来去停车场）：到了站的点离门至少 1 米、不来回弹
    print("8 西头月亮门 ↔ 后花园")
    m.ensure_canvas("garden")
    var gd = m.areas["garden"]
    var from_g: Vector2 = k.arrival_from("garden")
    k.reset_to(from_g + Vector2(0, -120))
    walk_to(k.spot_pos("to_garden"), 30.0)
    check("西头月亮门出去到了后花园（%s），站在北口里边 %s" % [m.state, gd.pos], m.state == "garden" and gd.pos == gd.arrival_from("lake"))
    tick(60)
    check("站着 60 帧不弹回湖边", m.state == "garden")
    walk_to(gd.spot_pos("to_lake"))
    check("后花园北口进来，站在西头门里边 %s" % k.pos, m.state == "lake" and k.pos == from_g)
    tick(60)
    check("站着 60 帧不弹回后花园", m.state == "lake")
    var east: Array = k.find_path(from_g, k.points["to_orchard"]["pos"])
    check("西头顺着湖岸走得到东头尽头（整条湖岸通）", not east.is_empty() and (east[east.size() - 1] as Vector2).distance_to(k.points["to_orchard"]["pos"]) <= 40.0)

    # 9. 一路走（01 F 10/4 验收）：东头月亮门进来 → 石板路 → 曲桥 → 亭子前沿 → 下桥 → 往西小路 → 西头湖尽头，真走（推着人走、不瞬移）
    print("9 一路走：月亮门 → 曲桥 → 亭子前沿 → 往西小路 → 西头")
    k.reset_to(k.SPAWN)
    var legs := [["石板路小广场", Vector2(2304, 870)], ["曲桥第一折", Vector2(2304, 760)], ["曲桥往东北那折", Vector2(2400, 712)],
        ["亭子前沿西头", Vector2(2260, 644)], ["亭子前沿东头", Vector2(2400, 644)], ["下桥回岸上", Vector2(2304, 800)],
        ["往西小路（东头像素画里）", Vector2(1700, 838)], ["接缝西边（色块）", Vector2(1450, 830)], ["西头湖尽头", Vector2(200, 820)]]
    for lg in legs:
        walk_to(lg[1], 40.0)
        check("走到%s %s（差 %.1f）" % [lg[0], k.pos, k.pos.distance_to(lg[1])], k.pos.distance_to(lg[1]) < 14.0 and m.state == "lake")

    DirAccess.remove_absolute("user://test_lake_games.json")
    DirAccess.remove_absolute("user://test_lake_court.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
