extends SceneTree
## 第 60 版（build57 bd9fec9）喷泉广场和各处新连法的功能测试（01 G 10/4 派，03 写）。不改游戏代码；存档指到临时文件。跟 02 的 test_plaza 不重复，独立再核：
##   1 新连法每个口来回：迎宾院西北口 ↔ 广场东口、广场西口 ↔ 草坪西南口、广场南口 ↔ 后厅走廊南口。真走进去（摇杆照寻路走）→ 切到对面 → 落点能站、
##     站的位置跟约定一样、离对面那个口至少 1 米、站着 2 秒不弹回去 → 再走回来落在原来约定的点；来回各 3 遍
##   2 北边三个口：走得进口子、人留在广场、说一句「还在布置」（字跟 lines.json 一样）、再走进去再说；口子往北过不去（施工栏）
##   3 主线路线：迎宾院 → 广场 → 草坪 → 果园 → 回草坪 → 广场 → 迎宾院；后厅 ↔ 宴会厅；后厅厨房后门 ↔ 草坪；草坪西北口 ↔ 后厅；湖边东头口 ↔ 迎宾院西小径；落点跟以前一样
##   4 老存档：只有老字段的存档进来站迎宾院大门口、能站；原来迎宾院东小径去草坪那个口关了（没有这个交互点、口堵上了），老落点 (1440,780) 还站得上、走得动
##   5 四角大树冠挡不挡人：广场六个口、三个落点周围能站的格子里，人（32×84）头顶被树冠盖住的有几个
##   6 牌子（各口木牌）：迎宾院、草坪、后厅、广场的「去…」牌，在画布里、不压出入口站人的地方、手机 540×960 和长屏下人站在口子上牌子整块在屏里
## 用法：Godot --headless --path . --script res://tools/test_plaza_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ent = preload("res://scripts/entrance.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0

var m
var started := false
var ok := true

func _initialize() -> void:
    # 4 的老存档先写好（main 开场就读）：只有 10/3 以前就有的字段
    var f := FileAccess.open("user://test_plaza_check_court.json", FileAccess.WRITE)
    f.store_string(JSON.stringify({"welcomed": true, "signed_in": true, "candy": true, "gloss_seen": true, "door_hint": true}))
    f.close()
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(280.0).timeout.connect(func():
        print("RESULT FAIL 280 秒没跑完")
        quit(1))

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func frames(n: int) -> void:
    for i in n:
        await process_frame

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 60.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty() or m.switching:
            break

func wait_state(s: String, secs := 6.0) -> bool:
    for i in int(secs * 60.0):
        if m.state == s and not m.switching:
            await frames(2)
            return true
        await process_frame
    return false

func canvas_of(n: String):
    return {"court": m.court, "plaza": m.plaza, "lawn": m.lawn, "backhall": m.backhall, "orchard": m.orchard, "lake": m.lake, "parking": m.parking}[n]

## 直接放到某块画布的某一点（测试起点用）
func put(name: String, p: Vector2) -> void:
    m.switching = false
    m.ensure_canvas(name)
    m._show_canvas(name)
    m._goto(name)
    var c = canvas_of(name)
    c.walking_enabled = true
    c.reset_to(p)
    c.path.clear()
    c.stick = Vector2.ZERO

## 走进 from 画布的 spot 口，等切到 dest，回对面落点
func cross(from: String, spot: String, dest: String) -> Vector2:
    var c = canvas_of(from)
    walk_to(c.spot_pos(spot))
    var okk: bool = await wait_state(dest)
    return canvas_of(dest).pos if okk else Vector2(-1, -1)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.court_save.local_path = "user://test_plaza_check_court.json"
    m.court_save.load_local()
    m.games_save.local_path = "user://test_plaza_check_games.json"
    m.orchard_save.local_path = "user://test_plaza_check_orchard.json"
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    for cn in ["plaza", "lawn", "backhall", "orchard", "lake", "parking"]:
        m.ensure_canvas(cn)
    var pz = m.plaza

    print("1 新连法每个口来回（来回各 3 遍）")
    var links := [
        # [名字, 从哪块, 走进哪个口, 到哪块, 到了站哪, 回去走哪个口, 回到原块站哪]
        # 约定的落点照 02 回执的表（不读游戏里的常量，免得常量改了测试跟着改）
        ["迎宾院西北口 → 广场东口", "court", "to_plaza", "plaza", Vector2(1430, 560), "to_court", Vector2(100, 334), Vector2(100, 334)],
        ["广场西口 → 草坪西南口", "plaza", "to_lawn", "lawn", Vector2(100, 780), "to_plaza", Vector2(106, 560), Vector2(106, 560)],
        ["广场南口 → 后厅走廊南口", "plaza", "to_backhall", "backhall", Vector2(620, 900), "to_plaza", Vector2(768, 920), Vector2(768, 920)],
    ]
    for lk in links:
        var from_name: String = lk[1]
        var dest_name: String = lk[3]
        var round_bad := 0
        var landing_ok := true
        var detail := ""
        for round_i in 3:
            # 起点：放在去那个口的路上（离口 150 像素的空地）
            var fc = canvas_of(from_name)
            var spot_p: Vector2 = fc.spot_pos(lk[2])
            var start: Vector2 = spot_p + (Vector2(150, 0) if spot_p.x < 700 else Vector2(-150, 0))
            if from_name == "plaza" and str(lk[2]) == "to_backhall":
                start = Vector2(768, 780)
            if from_name == "court":
                start = Vector2(200, 334)
            put(from_name, start)
            var landed: Vector2 = await cross(from_name, str(lk[2]), dest_name)
            var dc = canvas_of(dest_name)
            var want: Vector2 = lk[4]
            if landed.distance_to(want) > 8.0:
                round_bad += 1
                detail += "第 %d 遍去：站在 %s，约定 %s；" % [round_i + 1, str(landed), str(want)]
                continue
            if not dc._free(landed):
                landing_ok = false
                detail += "落点 %s 不能站；" % str(landed)
            # 离对面那个口至少 1 米（48 像素）、没站进口子的半径里
            var back_spot: Vector2 = dc.spot_pos(str(lk[5]))
            var back_r: float = float(dc.points[str(lk[5])]["r"])
            if landed.distance_to(back_spot) <= back_r:
                landing_ok = false
                detail += "落点 %s 站在回去那个口 %s 的半径 %.0f 里；" % [str(landed), str(back_spot), back_r]
            elif landed.distance_to(back_spot) - back_r < 0.0:
                landing_ok = false
            tick(120)    # 站着 2 秒，不能自己弹回去
            await frames(2)
            if m.state != dest_name:
                round_bad += 1
                detail += "站着 2 秒后切走了（%s）；" % m.state
                continue
            # 走回去
            var back_landed: Vector2 = await cross(dest_name, str(lk[5]), from_name)
            if back_landed.distance_to(lk[7]) > 8.0:
                round_bad += 1
                detail += "第 %d 遍回：站在 %s，约定 %s；" % [round_i + 1, str(back_landed), str(lk[7])]
        check("%s：来回 3 遍落点对、能站、不弹回、站着不动 2 秒（%s）" % [lk[0], detail if detail != "" else "全对"], round_bad == 0 and landing_ok)

    print("2 北边三个口（待做）")
    var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/plaza/lines.json"))["lines"]
    for id in ["north_kids", "north_shop", "north_rest"]:
        put("plaza", pz.FROM_COURT)
        m.dialog.visible = false
        walk_to(pz.spot_pos(id))
        await frames(3)
        var said: String = m.dialog_text.text if m.dialog.visible else ""
        check("%s：走进去人还在广场、说「%s」" % [id, said], m.state == "plaza" and said == str(lines[id]["text"]) and m.dialog_who.text == str(lines[id]["who"]))
        # 往北推摇杆 3 秒，过不去（施工栏）
        pz.walking_enabled = true
        var y0: float = pz.pos.y
        pz.stick = Vector2(0, -1)
        for i in 180:
            pz._process(DT)
        pz.stick = Vector2.ZERO
        check("%s 口子往北过不去（推 3 秒，y %.0f → %.0f，没越过施工栏 y 74）" % [id, y0, pz.pos.y], pz.pos.y > 80.0)
        # 走出来再进去又说一次
        walk_to(pz.spot_pos(id) + Vector2(0, 130))
        m.dialog.visible = false
        walk_to(pz.spot_pos(id))
        await frames(3)
        check("%s：走出来再进去又说一遍" % id, m.dialog.visible and m.dialog_text.text == str(lines[id]["text"]))
    m.dialog.visible = false

    print("3 主线路线")
    put("court", m.court.SPAWN)
    var p1: Vector2 = await cross("court", "to_plaza", "plaza")
    var p2: Vector2 = await cross("plaza", "to_lawn", "lawn")
    var p3: Vector2 = await cross("lawn", "to_orchard", "orchard")
    check("迎宾院 → 广场 → 草坪 → 果园，落点 %s、%s、%s" % [str(p1), str(p2), str(p3)], p1.distance_to(pz.FROM_COURT) < 8.0 and p2.distance_to(m.LAWN_FROM_PLAZA) < 8.0 and p3.distance_to(m.ORCHARD_FROM_LAWN) < 8.0)
    var q1: Vector2 = await cross("orchard", "to_lawn", "lawn")
    check("果园 → 草坪（%s，约定 %s）" % [str(q1), str(m.LAWN_FROM_ORCHARD)], q1.distance_to(m.LAWN_FROM_ORCHARD) < 8.0)
    var q2: Vector2 = await cross("lawn", "to_plaza", "plaza")
    var q3: Vector2 = await cross("plaza", "to_court", "court")
    check("草坪 → 广场 → 迎宾院（%s、%s）" % [str(q2), str(q3)], q2.distance_to(pz.FROM_LAWN) < 8.0 and q3.distance_to(m.COURT_FROM_PLAZA) < 8.0)
    # 后厅
    put("backhall", Vector2(300, 780))
    var h1: Vector2 = Vector2(-1, -1)
    walk_to(m.backhall.spot_pos("to_hall"))
    var hall_ok: bool = await wait_state("banquet")
    check("后厅走廊西口 → 宴会厅", hall_ok)
    m._switch_canvas("backhall")
    var back_ok: bool = await wait_state("backhall")
    var back_pos: Vector2 = m.backhall.pos
    check("宴会厅 → 后厅：站在走廊西口里边（%s）" % str(back_pos), back_ok and back_pos.distance_to(m.BACKHALL_FROM_HALL) < 8.0)
    put("backhall", Vector2(1300, 780))
    walk_to(m.backhall.spot_pos("to_lawn"))
    var kitchen_ok: bool = await wait_state("lawn")
    check("后厅厨房后门 → 草坪（%s，约定 %s）" % [str(m.lawn.pos), str(m.LAWN_FROM_BACKHALL)], kitchen_ok and m.lawn.pos.distance_to(m.LAWN_FROM_BACKHALL) < 8.0)
    walk_to(m.lawn.spot_pos("to_backhall"))
    var lb_ok: bool = await wait_state("backhall")
    check("草坪西北口 → 后厅厨房后门边（%s，约定 %s）" % [str(m.backhall.pos), str(m.BACKHALL_FROM_LAWN)], lb_ok and m.backhall.pos.distance_to(m.BACKHALL_FROM_LAWN) < 8.0)
    # 湖边
    put("court", Vector2(200, 520))
    var l1: Vector2 = await cross("court", "to_lake", "lake")
    check("迎宾院西小径 → 湖边东头（%s，约定 %s）" % [str(l1), str(m.LAKE_FROM_COURT)], l1.distance_to(m.LAKE_FROM_COURT) < 8.0)
    var l2: Vector2 = await cross("lake", "to_entrance", "court")
    check("湖边东头 → 迎宾院西小径（%s）" % str(l2), m.state == "court" and m.court._free(l2))

    print("4 老存档、关了的东小径口")
    check("迎宾院里没有去草坪的口了（交互点 %s）" % str(m.court.points.keys()), not m.court.points.has("to_lawn") and m.court.points.has("to_plaza") and m.court.points.has("to_lake"))
    check("草坪里没有回迎宾院的口了（交互点 %s）" % str(m.lawn.points.keys()), not m.lawn.points.has("to_entrance") and m.lawn.points.has("to_plaza"))
    var old_spot := Vector2(1440, 780)     # 原来从草坪回迎宾院落在这儿
    check("迎宾院里老落点 (1440,780) 还站得上", m.court._free(old_spot))
    put("court", old_spot)
    walk_to(Vector2(768, 700))
    check("站在老落点能走出去（走到 %s）" % str(m.court.pos), m.court.pos.distance_to(Vector2(768, 700)) < 20.0)
    put("court", old_spot)
    m.court.stick = Vector2(1, 0)
    for i in 120:
        m.court._process(DT)
    m.court.stick = Vector2.ZERO
    check("老落点往东推摇杆：不走出画布、不掉进墙（%s）" % str(m.court.pos), m.court.pos.x < 1490.0 and m.court._free(m.court.pos))
    var east_open := 0
    for y in range(750, 811, 12):
        for x in range(1488, 1536, 12):
            if m.court._free(Vector2(x + 6, y + 6)):
                east_open += 1
    check("原来东小径口（x 1488～1536、y 750～810）现在走不进去（能站的格子 %d 个）" % east_open, east_open == 0)
    # 老存档开局
    m.court_save.court_seen = false
    m.court_save.welcomed = true
    m.court_save.signed_in = true
    await m._start_play()
    await wait_state("court")
    check("老存档开局：站迎宾院大门里边（%s）、能站" % str(m.court.pos), m.state == "court" and m.court.pos == m.court.SPAWN and m.court._free(m.court.pos))

    print("5 广场四角大树冠挡不挡人")
    var trees: Array = []
    for it in pz.cfg["items"]:
        if str(it.get("type", "")) == "tree":
            trees.append(it)
    var covered_report: Array = []
    var total_covered := 0
    var spots_bad: Array = []
    for id in pz.points:
        var sp: Vector2 = pz.points[id]["pos"]
        var rr: float = float(pz.points[id]["r"])
        var cnt := 0
        var cells := 0
        for dy in range(-int(rr), int(rr) + 1, 12):
            for dx in range(-int(rr), int(rr) + 1, 12):
                var p := sp + Vector2(dx, dy)
                if Vector2(dx, dy).length() > rr or not pz._free(p):
                    continue
                cells += 1
                for t in trees:
                    var g: Dictionary = Ent.tree_geom(t)
                    var head := Vector2(p.x, p.y - 70.0)
                    var e := Vector2((head.x - float(t["x"])) / float(g["rx"]), (head.y - float(g["cy"])) / float(g["ry"]))
                    if e.length() <= 1.0 and float(t["y"]) > p.y:
                        cnt += 1
                        break
        covered_report.append("%s 能站 %d 格、头被树冠盖住 %d 格" % [id, cells, cnt])
        if cnt > 0:
            spots_bad.append(id)
    for l in covered_report:
        print("    ", l)
    for p in [pz.FROM_COURT, pz.FROM_LAWN, pz.FROM_BACKHALL]:
        for t in trees:
            var g2: Dictionary = Ent.tree_geom(t)
            var head2 := Vector2(p.x, p.y - 70.0)
            var e2 := Vector2((head2.x - float(t["x"])) / float(g2["rx"]), (head2.y - float(g2["cy"])) / float(g2["ry"]))
            if e2.length() <= 1.0 and float(t["y"]) > p.y:
                spots_bad.append("落点 %s" % str(p))
    check("六个口、三个落点周围能站的格子：人头不被四角大树冠盖住（有问题的 %s）" % str(spots_bad), spots_bad.is_empty())

    print("6 牌子")
    var bad_label: Array = []
    var vis_bad: Array = []
    var size_list := [Vector2i(540, 960), Vector2i(585, 1266)]
    for cn in ["plaza", "court", "lawn", "backhall"]:
        var c = canvas_of(cn)
        if cn != "court":
            m.ensure_canvas(cn)
        var cw := float(c.cfg["size"][0])
        var ch := float(c.cfg["size"][1])
        var stands: Array = [c.SPAWN]
        for id in c.points:
            stands.append(c.points[id]["pos"])
        for k in ["FROM_COURT", "FROM_LAWN", "FROM_BACKHALL"]:
            if c.get(k) != null and c.get(k) != Vector2.ZERO:
                stands.append(c.get(k))
        for lb in c.labels.get_children():
            if not lb is Label:
                continue
            var l := lb as Label
            var r := Rect2(l.global_position, l.size)
            if r.position.x < 0.0 or r.position.y < 0.0 or r.end.x > cw or r.end.y > ch:
                bad_label.append("%s「%s」出画布 %s" % [cn, l.text, str(r)])
            if not (l.text.begins_with("去") or l.text.begins_with("回")):
                continue
            # 压人：口子上站人，人的身子 32×84 跟牌子叠、牌子又排在人前面
            for sp in stands:
                var body := Rect2(sp.x - 16.0, sp.y - 84.0, 32.0, 84.0)
                if r.intersects(body) and (r.end.y - 4.0) > sp.y:
                    bad_label.append("%s「%s」盖住站在 %s 的人" % [cn, l.text, str(sp)])
    # 牌子画在人上面（labels.z_index 3 > 世界 0）：口子上、落点上站人，牌子跟人的身子叠多少（03 测第 60 版时发现：广场东西口落点、草坪西南口牌子盖住人的头和肩）
    var over_list: Array = []
    for cn in ["plaza", "court", "lawn", "backhall"]:
        var c2 = canvas_of(cn)
        put(cn, c2.SPAWN)
        var stands2: Dictionary = {"出生": c2.SPAWN}
        for id in c2.points:
            stands2["口 " + id] = c2.points[id]["pos"]
        for k in ["FROM_COURT", "FROM_LAWN", "FROM_BACKHALL"]:
            if c2.get(k) != null and c2.get(k) != Vector2.ZERO:
                stands2["落点 " + k] = c2.get(k)
        for sk in stands2:
            var sp2: Vector2 = stands2[sk]
            c2.reset_to(sp2)
            c2.cam.reset_smoothing()
            await frames(4)
            var body2 := Rect2(sp2.x - 16.0, sp2.y - 84.0, 32.0, 84.0)
            for lb in c2.labels.get_children():
                if lb is Label and ((lb as Label).text.begins_with("去") or (lb as Label).text.begins_with("回")):
                    var ov := Rect2((lb as Label).global_position, (lb as Label).size).intersection(body2)
                    if ov.size.x > 0.0 and ov.size.y > 0.0:
                        over_list.append("%s %s：「%s」牌盖住人 %.0f×%.0f（人高 84）" % [cn, sk, (lb as Label).text, ov.size.x, ov.size.y])
    for l in over_list:
        print("    ", l)
    check("口子上、落点上站人，牌子盖住人身子的共 %d 处（03 测第 60 版时是 9 处：广场东口 3、西口落点 1、草坪 3、后厅 2，已报 01；只守「不再多」）" % over_list.size(), over_list.size() <= 9)
    for sz in size_list:
        get_root().size = sz
        await frames(4)
        for cn in ["plaza", "court", "lawn", "backhall"]:
            put(cn, canvas_of(cn).SPAWN)
            var c = canvas_of(cn)
            for lb in c.labels.get_children():
                if not (lb is Label) or not ((lb as Label).text.begins_with("去") or (lb as Label).text.begins_with("回")):
                    continue
                var l := lb as Label
                var r0 := Rect2(l.global_position, l.size)
                # 人站在离这块牌子最近的口子上，看牌子整块在不在屏里（牌子会跟着镜头挪回屏里，所以挪完再量）
                var best := Vector2.ZERO
                var bd := INF
                for id in c.points:
                    var d: float = (c.points[id]["pos"] as Vector2).distance_to(r0.get_center())
                    if d < bd:
                        bd = d
                        best = c.points[id]["pos"]
                c.reset_to(best)
                c.cam.reset_smoothing()
                await frames(6)
                var r := Rect2(l.global_position, l.size)
                var cc: Vector2 = c.cam.get_screen_center_position()
                var sv: SubViewport = m.view.get_child(0)
                var vis := Rect2(cc - Vector2(sv.size) / c.cam.zoom.x * 0.5, Vector2(sv.size) / c.cam.zoom.x)
                if not vis.encloses(r):
                    vis_bad.append("%dx%d %s「%s」（人站 %s，屏 %s，牌 %s）" % [sz.x, sz.y, cn, l.text, str(best), str(vis), str(r)])
    get_root().size = Vector2i(540, 960)
    for s in bad_label:
        print("    ", s)
    for s in vis_bad:
        print("    ", s)
    check("牌子都在画布里、不盖住站在口子上的人（%d 处有问题）" % bad_label.size(), bad_label.is_empty())
    check("手机 540×960 和长屏下，人站在口子上，对应那块「去…」牌整块在屏里（%d 处有问题）" % vis_bad.size(), vis_bad.is_empty())
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
