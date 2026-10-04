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
    if m.areas.has(n):
        return m.areas[n]
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

    # 10/4 连图（02 E 照新连法改，01 G 派）：游戏里各块照阿鱼图转半圈摆，广场的口换了边——
    # 迎宾院东口 ↔ 广场西口、广场东口 ↔ 草坪西南口、广场北口 ↔ 后厅走廊南口；北边三个「待做」口改成南边三个口，通儿童乐园、小卖部、休息厅 2 灰盒。
    # 落点不再写死，照布局算（对面通回来的那个口往里 70 像素，一定在那个口的圈外）；每条路的全面来回在 test_liantu.gd
    print("1 新连法每个口来回（来回各 3 遍）")
    var links := [
        # [名字, 从哪块, 走进哪个口, 到哪块, 回去走哪个口]
        ["迎宾院东口 → 广场西口", "court", "to_plaza", "plaza", "to_court"],
        ["广场东口 → 草坪西南口", "plaza", "to_lawn", "lawn", "to_plaza"],
        ["广场北口 → 后厅走廊南口", "plaza", "to_backhall", "backhall", "to_plaza"],
    ]
    for lk in links:
        var from_name: String = lk[1]
        var dest_name: String = lk[3]
        var round_bad := 0
        var landing_ok := true
        var detail := ""
        for round_i in 3:
            var fc = canvas_of(from_name)
            put(from_name, fc.arrival_at(str(lk[2])))
            var landed: Vector2 = await cross(from_name, str(lk[2]), dest_name)
            var dc = canvas_of(dest_name)
            var want: Vector2 = dc.arrival_at(str(lk[4]))
            if landed.distance_to(want) > 8.0:
                round_bad += 1
                detail += "第 %d 遍去：站在 %s，该站 %s；" % [round_i + 1, str(landed), str(want)]
                continue
            if not dc._free(landed):
                landing_ok = false
                detail += "落点 %s 不能站；" % str(landed)
            var back_spot: Vector2 = dc.spot_pos(str(lk[4]))
            var back_r: float = float(dc.points[str(lk[4])]["r"])
            if landed.distance_to(back_spot) <= back_r:
                landing_ok = false
                detail += "落点 %s 站在回去那个口 %s 的半径 %.0f 里；" % [str(landed), str(back_spot), back_r]
            tick(120)    # 站着 2 秒，不能自己弹回去
            await frames(2)
            if m.state != dest_name:
                round_bad += 1
                detail += "站着 2 秒后切走了（%s）；" % m.state
                continue
            var back_landed: Vector2 = await cross(dest_name, str(lk[4]), from_name)
            var back_want: Vector2 = fc.arrival_at(str(lk[2]))
            if back_landed.distance_to(back_want) > 8.0:
                round_bad += 1
                detail += "第 %d 遍回：站在 %s，该站 %s；" % [round_i + 1, str(back_landed), str(back_want)]
        check("%s：来回 3 遍落点对、能站、不弹回、站着不动 2 秒（%s）" % [lk[0], detail if detail != "" else "全对"], round_bad == 0 and landing_ok)

    print("2 南边三个口（原来北边三个「待做」口，10/4 起通三块灰盒）")
    var lines: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/areas/lines.json"))["lines"]
    for aid in ["kids", "shop", "rest2"]:
        put("plaza", pz.arrival_at("to_" + aid))
        var landed: Vector2 = await cross("plaza", "to_" + aid, aid)
        var ac = canvas_of(aid)
        check("广场南口 → %s（站在 %s）" % [aid, str(landed)], m.state == aid and landed.distance_to(ac.arrival_at("to_plaza")) < 8.0)
        m.dialog.visible = false
        walk_to(ac.spot_pos("wip"))
        await frames(3)
        var said: String = m.said_raw if m.dialog.visible else ""
        check("%s：走到当中说「%s」、人还在那块" % [aid, said], m.state == aid and said == str(lines[aid + "_wip"]["text"]))
        var back: Vector2 = await cross(aid, "to_plaza", "plaza")
        check("%s 北口回广场（站在 %s）" % [aid, str(back)], m.state == "plaza" and back.distance_to(pz.arrival_at("to_" + aid)) < 8.0)
    m.dialog.visible = false

    print("3 主线路线")
    put("court", m.court.arrival_at("to_plaza"))
    var p1: Vector2 = await cross("court", "to_plaza", "plaza")
    var p2: Vector2 = await cross("plaza", "to_lawn", "lawn")
    var p3: Vector2 = await cross("lawn", "to_orchard", "orchard")
    check("迎宾院 → 广场 → 草坪 → 果园 A，落点 %s、%s、%s" % [str(p1), str(p2), str(p3)], p1.distance_to(pz.arrival_at("to_court")) < 8.0
        and p2.distance_to(m.lawn.arrival_at("to_plaza")) < 8.0 and p3.distance_to(m.orchard.arrival_at("to_lawn")) < 8.0)
    var q1: Vector2 = await cross("orchard", "to_lawn", "lawn")
    check("果园 A → 草坪（%s）" % str(q1), q1.distance_to(m.lawn.arrival_at("to_orchard")) < 8.0)
    var q2: Vector2 = await cross("lawn", "to_plaza", "plaza")
    var q3: Vector2 = await cross("plaza", "to_court", "court")
    check("草坪 → 广场 → 迎宾院（%s、%s）" % [str(q2), str(q3)], q2.distance_to(pz.arrival_at("to_lawn")) < 8.0 and q3.distance_to(m.court.arrival_at("to_plaza")) < 8.0)
    # 后厅
    put("backhall", Vector2(300, 780))
    walk_to(m.backhall.spot_pos("to_hall"))
    var hall_ok: bool = await wait_state("banquet")
    check("后厅走廊西口 → 宴会厅", hall_ok)
    m._switch_canvas("backhall")
    var back_ok: bool = await wait_state("backhall")
    var back_pos: Vector2 = m.backhall.pos
    check("宴会厅 → 后厅：站在走廊西口里边（%s）" % str(back_pos), back_ok and back_pos.distance_to(m.backhall.arrival_at("to_hall")) < 8.0)
    put("backhall", Vector2(1300, 780))
    walk_to(m.backhall.spot_pos("to_lawn"))
    var kitchen_ok: bool = await wait_state("lawn")
    check("后厅厨房后门 → 草坪（%s）" % str(m.lawn.pos), kitchen_ok and m.lawn.pos.distance_to(m.lawn.arrival_at("to_backhall")) < 8.0)
    walk_to(m.lawn.spot_pos("to_backhall"))
    var lb_ok: bool = await wait_state("backhall")
    check("草坪西北口 → 后厅厨房后门边（%s）" % str(m.backhall.pos), lb_ok and m.backhall.pos.distance_to(m.backhall.arrival_at("to_lawn")) < 8.0)
    # 湖边：10/4 起从后花园（西头月亮门）、果园 A（东头尽头）进
    put("orchard", m.orchard.arrival_at("to_lake"))
    var l1: Vector2 = await cross("orchard", "to_lake", "lake")
    check("果园 A 西口 → 湖边东头尽头（%s）" % str(l1), l1.distance_to(m.lake.arrival_at("to_orchard")) < 8.0)
    var l2: Vector2 = await cross("lake", "to_orchard", "orchard")
    check("湖边东头尽头 → 果园 A（%s）" % str(l2), m.state == "orchard" and m.orchard._free(l2))

    print("4 老存档、关了的口、重开的口")
    # 第 68 版（07）：迎宾院东边去停车场的口不要了，南边大门（gate）出去就是停车场（停车场往西放大、在迎宾院正下方）
    check("迎宾院：没有去草坪、去湖边、东边去停车场的口了，西北口去广场、南边大门去停车场（交互点 %s）" % str(m.court.points.keys()),
        not m.court.points.has("to_lawn") and not m.court.points.has("to_lake") and m.court.points.has("to_plaza") and not m.court.points.has("to_parking") and m.court.points.has("gate"))
    check("草坪里没有回迎宾院的口了（交互点 %s）" % str(m.lawn.points.keys()), not m.lawn.points.has("to_entrance") and m.lawn.points.has("to_plaza"))
    var west_open := 0
    for y in range(486, 555, 12):
        for x in range(0, 48, 12):
            if m.court._free(Vector2(x + 6, y + 6)):
                west_open += 1
    check("原来西小径口（x 0～48、y 486～554）现在走不进去（能站的格子 %d 个）" % west_open, west_open == 0)
    # 老存档开局：10/4 起每次都开车进来，停车场下车
    m.court_save.court_seen = false
    m.court_save.welcomed = true
    m.court_save.signed_in = true
    await m._start_play()
    await wait_state("parking")
    check("老存档开局：开车进来，停车场自己车旁下车（%s）、能站" % str(m.parking.pos), m.state == "parking" and m.parking.pos == m.parking.SPAWN and m.parking._free(m.parking.pos))

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
    for p in pz.points.keys().filter(func(k): return str(pz.points[k]["to"]) != "").map(func(k): return pz.arrival_at(k)):   # 10/4 连图：八个口的落点
        for t in trees:
            var g2: Dictionary = Ent.tree_geom(t)
            var head2 := Vector2(p.x, p.y - 70.0)
            var e2 := Vector2((head2.x - float(t["x"])) / float(g2["rx"]), (head2.y - float(g2["cy"])) / float(g2["ry"]))
            if e2.length() <= 1.0 and float(t["y"]) > p.y:
                spots_bad.append("落点 %s" % str(p))
    check("各口、各落点周围能站的格子：人头不被四角大树冠盖住（有问题的 %s）" % str(spots_bad), spots_bad.is_empty())

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
