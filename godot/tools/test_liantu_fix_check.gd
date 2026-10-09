extends SceneTree
## 第 65 版接着修的三条（01 G 10/4 派，03 自己量，不改游戏代码）：
##   1 宴会厅服务员改从西墙那道门端菜进出：门点在 (70,1300) 能站、不在东侧门边；放 150 秒，每位服务员的「端盘出发点」「空盘回到点」都在西门边、
##     不在东侧门（1516,1289）边 150 像素内出现过；路上每一帧踩的地方都能走；真的上了菜、真的进出了门；西门到各桌有路
##   2 西墙那道门的门框：照东侧门底图上量的样子（五层颜色一圈圈叠）逐像素比：把东侧门那块底图左右翻过来，跟代码画的西门比颜色，对上几成；
##     门框叠在人和桌子下面（z 在底图上面、人下面）；门前后 80 像素的格子都能走（不挡路）；从落点推摇杆往西走得进门
##   3 草坪东边三个口：三个口 y 间距 ≥ 170、圈 18、互相不叠；东边这一线能站的地方只在三个口那儿（灌木边只留缺口）；
##     碎石小路接通：中间南北路 → 三个口都有路；从广场那个口的落点沿小路走到后厅口，路上离另外两个口圆心一直 > 圈半径；树 tree_28 拿掉了；
##     西餐厨房、广场两个口的落点站在小路上、在两个口中间
## 用法：Godot --headless --path . --script res://tools/test_liantu_fix_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(250.0).timeout.connect(func():
        print("RESULT FAIL 250 秒没跑完")
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

func go_canvas(k: String) -> void:
    m.switching = false
    m._show_canvas(k)
    m._goto(k)
    m.cv.walking_enabled = true
    m.cv.stick = Vector2.ZERO
    m.cv.path.clear()

func color_close(a: Color, b: Color, tol := 24.0) -> bool:
    return absf(a.r8 - b.r8) + absf(a.g8 - b.g8) + absf(a.b8 - b.b8) <= tol

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.court_save.local_path = "user://test_fix_court.json"
    m.games_save.local_path = "user://test_fix_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    m.ensure_canvas("lawn")
    await m._enter_court()
    m.dialog.visible = false
    var h = m.hall
    var life = h.life

    print("1 服务员从西门端菜")
    var door: Vector2 = life.door
    var ewd: Vector2 = h.exits[0]["pos"]
    print("    服务员的门 %s；西墙那道门 %s；东侧门 %s" % [str(door), str(h.side_door), str(ewd)])
    check("服务员的门（%s）在西门边（离西墙那道门 %s 不到 80 像素）、不在东侧门边、能站" % [str(door), str(h.side_door)], door.distance_to(h.side_door) < 80.0 and door.distance_to(ewd) > 800.0 and h._free(door))
    go_canvas("banquet")
    h.reset_to(h.SPAWN)
    await frames(2)
    var n_w: int = life.waiters.size()
    var starts: Array = []   # 端盘出发（state 变成 carry 那一帧）的位置
    var ends: Array = []     # 空盘回到（state 变成 away）的位置
    var last_state := {}
    var off_ground := 0
    var samples := 0
    var min_east := INF
    var hid_at_door := 0
    var dishes0: int = life.dishes.size()
    var placed_total := 0
    var seen_dishes := {}
    var t_sim := 0.0
    while t_sim < 150.0:
        life._process(1.0 / 30.0)
        t_sim += 1.0 / 30.0
        for w in life.waiters:
            if str(w.kind) != "waiter":
                continue
            var st: String = str(w.state)
            var key: int = w.get_instance_id()
            if last_state.get(key, "") != st:
                if last_state.has(key):   # 第一次看见这位（放的时候已经走在半路上了）不算「出发」
                    if st == "carry":
                        starts.append(w.pos)
                    elif st == "away":
                        ends.append(w.pos)
                        if not (w.node as Node2D).visible:
                            hid_at_door += 1
                last_state[key] = st
            if st != "away":
                samples += 1
                if not h._free(w.pos, 0.0) and w.pos.distance_to(door) > 30.0:
                    off_ground += 1
                min_east = minf(min_east, (w.pos as Vector2).distance_to(ewd))
        for dd in life.dishes:
            seen_dishes[dd["spr"].get_instance_id()] = true
    var far_starts := 0
    for p in starts:
        if (p as Vector2).distance_to(door) > 60.0:
            far_starts += 1
    var far_ends := 0
    for p in ends:
        if (p as Vector2).distance_to(door) > 60.0:
            far_ends += 1
    print("    放 150 秒：%d 位服务员；端盘出发 %d 次、空盘回到门 %d 次、上桌的菜 %d 盘；路上 %d 个采样点里不在能走的格子上的 %d 个；离东侧门最近 %.0f 像素" % [n_w, starts.size(), ends.size(), seen_dishes.size(), samples, off_ground, min_east])
    check("每次端盘出发、空盘回来都在西门边 60 像素内（出发 %d 次、回来 %d 次、偏的 %d + %d）" % [starts.size(), ends.size(), far_starts, far_ends], starts.size() >= 6 and ends.size() >= 6 and far_starts == 0 and far_ends == 0)
    check("150 秒里真上了菜（%d 盘）、回到门里的人藏起来了（%d 次）" % [seen_dishes.size(), hid_at_door], seen_dishes.size() >= 6 and hid_at_door >= 6)
    check("路上踩的地方都能走（%d / %d 个不能）、离东侧门最近 %.0f 像素（没人走东边）" % [off_ground, samples, min_east], off_ground == 0 and min_east > 150.0)
    var path_bad := 0
    for t in h.cfg["tables"]:
        var tc: Vector2 = h._seat_center(t)
        if h.find_path(door, tc).is_empty():
            path_bad += 1
    check("西门到每一桌都有路（%d 桌，走不到的 %d 桌）" % [(h.cfg["tables"] as Array).size(), path_bad], path_bad == 0)

    print("2 西墙那道门的门框")
    var base_path: String = str(h.cfg["base"])
    var base_img: Image = load(base_path).get_image()
    if base_img.is_compressed():
        base_img.decompress()
    base_img.convert(Image.FORMAT_RGBA8)
    var W := int(h.cfg["size"][0])
    var wd = h.get_node_or_null("west_door")
    check("宴会厅有「west_door」这个门框节点、在底图上面（z %s）" % str(wd.z_index if wd != null else "无"), wd != null and wd.z_index > -10 and wd.z_index < 0)
    # 代码画的西门，逐像素栅格化（各层从外往里叠），跟底图上东侧门那块（左右翻过来）比
    var DW := 40
    var DH := 58
    var west := Image.create(DW, DH, false, Image.FORMAT_RGBA8)
    west.fill(Color(0, 0, 0, 0))
    for r in h.WEST_DOOR_RECTS:
        var col := Color(str(r[4]))
        for yy in range(int(r[2]), int(r[3])):
            for xx in range(int(r[0]), int(r[1])):
                west.set_pixel(xx, yy, col)
    var east_top := 1260
    var match_n := 0
    var tot := 0
    var worst_row := {}
    for yy in DH:
        for xx in DW:
            var ec: Color = base_img.get_pixel(W - 1 - xx, east_top + yy)   # 东侧门那块左右翻过来
            var wc: Color = west.get_pixel(xx, yy)
            if wc.a == 0.0:
                continue
            tot += 1
            if color_close(ec, wc, 40.0):
                match_n += 1
            else:
                worst_row[yy] = int(worst_row.get(yy, 0)) + 1
    var pct := 100.0 * float(match_n) / float(maxi(tot, 1))
    print("    西门（代码画 40×58）对东侧门底图（左右翻过来）：%d / %d 像素颜色接近（容差 40）= %.0f%%；对不上的行 %s" % [match_n, tot, pct, str(worst_row.keys().slice(0, 12))])
    check("西门门框颜色跟东侧门底图对上 %.0f%%（要求 ≥ 80%%）" % pct, pct >= 80.0)
    # 门前后能走：门点往厅里每 8 像素到 120 像素的格子能站，门上下 24 像素也能站
    var walk_bad: Array = []
    var all_nf: Array = []
    for dx in range(0, 121, 8):
        for dy in [-24, 0, 24]:
            var q: Vector2 = h.side_door + Vector2(float(dx), float(dy))
            if not h._free(q):
                all_nf.append(q)
                if dx >= int(h.side_door_r) + 8 and dx <= 96:
                    walk_bad.append(q)   # 出口圈（半径 34）外面、往厅里 96 像素（再往里是西门口那张大桌的桌脚，离门 112 像素）必须能站
    var in_circle := false
    for dy in range(-30, 31, 6):
        for dx in range(0, 35, 6):
            var q2: Vector2 = h.side_door + Vector2(float(dx), float(dy))
            if q2.distance_to(h.side_door) < h.side_door_r and h._free(q2):
                in_circle = true
    print("    门点往厅里 0～120 像素、上下 24 像素里不能站的点（门在墙里，墙那几格本来不能站）：%s" % str(all_nf))
    check("西门口出口圈（半径 %.0f）里有能站的格子、圈外往厅里 96 像素全能站（不能站的 %d 个点）；再往里 112 像素起是一张大桌的桌脚" % [h.side_door_r, walk_bad.size()], in_circle and walk_bad.is_empty())
    h.reset_to(h.side_arrive)
    go_canvas("banquet")
    h.walking_enabled = true
    await frames(2)
    h.stick = Vector2(-1, 0)
    var left_out := false
    for i in 240:
        h._process(DT)
        m._process(DT)
        if m.state != "banquet":
            left_out = true
            break
    h.stick = Vector2.ZERO
    check("从西门落点推摇杆往西走，一路走进门、出门去后厅（%s，停在 %s）" % [str(left_out), m.state], left_out and m.state in ["backhall", "banquet"] and m.state == "backhall")

    print("3 草坪东边三个口")
    var lw = m.lawn
    go_canvas("lawn")
    await frames(2)
    var ex: Dictionary = {}
    for id in ["to_backhall", "to_wkitchen", "to_plaza"]:
        ex[id] = lw.points[id]
    var ys: Array = []
    for id in ex:
        ys.append(float((ex[id]["pos"] as Vector2).y))
    ys.sort()
    print("    三个口 y %s；圈 %s" % [str(ys), str([ex["to_backhall"]["r"], ex["to_wkitchen"]["r"], ex["to_plaza"]["r"]])])
    check("三个口 y 间距 ≥ 170（%s）、圈半径 18、圈不叠" % str(ys), ys[1] - ys[0] >= 170.0 and ys[2] - ys[1] >= 170.0 and float(ex["to_backhall"]["r"]) == 18.0 and float(ex["to_wkitchen"]["r"]) == 18.0 and float(ex["to_plaza"]["r"]) == 18.0)
    # 东边这一线（x 1500～1530）能站的格子沿 y 排成几段：该只有三个口各一段
    var runs: Array = []
    var in_run := false
    var y0 := 0.0
    for yy in range(0, 1024, 6):
        var any := false
        for xx in [1530.0]:
            if lw._free(Vector2(xx, float(yy) + 3.0)):
                any = true
        if any and not in_run:
            in_run = true
            y0 = float(yy)
        elif not any and in_run:
            in_run = false
            runs.append([y0, float(yy)])
    if in_run:
        runs.append([y0, 1024.0])
    print("    东边灌木边（x 1530 那一列）能站的 y 段：%s" % str(runs))
    var runs_ok := runs.size() == 3
    if runs_ok:
        for i in 3:
            var yy: float = ys[i]
            if not (float(runs[i][0]) - 30.0 <= yy and yy <= float(runs[i][1]) + 30.0):
                runs_ok = false
    check("东边灌木边只在三个口那儿留缺口：能站的段 %d 段、各含一个口" % runs.size(), runs_ok)
    # 路网：中间南北路上一点 → 三个口；从广场口落点走到后厅口，路上离另外两个口圆心的最小距离
    var hub := Vector2(768, 560)
    var hub_ok := true
    var hub_msg: Array = []
    for id in ex:
        var pth: Array = lw.find_path(lw.nearest_free(hub), ex[id]["pos"])
        hub_msg.append("%s %s" % [id, "通" if not pth.is_empty() else "不通"])
        hub_ok = hub_ok and not pth.is_empty()
    check("中间南北路上一点到三个口都有路（%s）" % str(hub_msg), hub_ok)
    var legs := [["to_plaza", "to_backhall"], ["to_backhall", "to_plaza"], ["to_plaza", "to_wkitchen"], ["to_wkitchen", "to_backhall"]]
    var worst := INF
    var leg_msg: Array = []
    var leg_ok := true
    for lg in legs:
        go_canvas("lawn")
        lw.reset_to(lw.arrival_at(str(lg[0])))
        tick(3)
        var others: Array = []
        for id in ex:
            if id != str(lg[1]):
                others.append(id)
        var target: Vector2 = ex[str(lg[1])]["pos"]
        lw.go_to(target)
        var mind := INF
        var arrived := false
        for i in int(40.0 / DT):
            tick(1)
            if m.state != "lawn":
                arrived = true
                break
            for id in others:
                if id == str(lg[0]):
                    continue
                mind = minf(mind, lw.pos.distance_to(ex[id]["pos"]) - float(ex[id]["r"]))
            if lw.path.is_empty():
                break
        worst = minf(worst, mind)
        leg_msg.append("%s→%s 到 %s、离别的口圈最近 %.0f" % [str(lg[0]), str(lg[1]), str(arrived), mind])
        # 弹开了去别的块也算失败：m.state 变了但不是到目标那个口
        if not arrived or mind <= 0.0:
            leg_ok = false
    print("    ", leg_msg)
    check("沿小路在三个口之间走，到得了目标口、路上没踩进别的口的圈（离圈最近 %.0f 像素）" % worst, leg_ok)
    # 玩家自己推摇杆：从广场口的落点一直往北推，路过西餐厨房口到后厅口，一路离西餐厨房口的圈最近多少、有没有被带走
    go_canvas("lawn")
    lw.reset_to(lw.arrival_at("to_plaza"))
    tick(3)
    lw.stick = Vector2(0, -1)
    var mind2 := INF
    var went := ""
    for i in int(12.0 / DT):
        tick(1)
        if m.state != "lawn":
            went = m.state
            break
        mind2 = minf(mind2, lw.pos.distance_to(ex["to_wkitchen"]["pos"]) - float(ex["to_wkitchen"]["r"]))
    lw.stick = Vector2.ZERO
    print("    从广场口落点一直往北推：走到 %s，离西餐厨房口的圈最近 %.0f 像素，%s" % [str(lw.pos), mind2, ("被带去 " + went) if went != "" else "没被带走"])
    check("一直往北推摇杆路过西餐厨房口：没被带去西餐厨房（%s），离圈 ≥ 8 像素（最近 %.0f）" % [went, mind2], went == "" and mind2 >= 8.0)
    var tree28 := false
    for it in lw.cfg["items"]:
        if str(it.get("id", "")) == "tree_28":
            tree28 = true
    check("原来盖在第三个口上的树 tree_28 拿掉了", not tree28)
    var land_wk: Vector2 = lw.arrival_at("to_wkitchen")
    var land_pz: Vector2 = lw.arrival_at("to_plaza")
    var ex_ys: Array = [float(ex["to_backhall"]["pos"].y), float(ex["to_wkitchen"]["pos"].y), float(ex["to_plaza"]["pos"].y)]
    print("    西餐厨房回来站 %s、广场回来站 %s" % [str(land_wk), str(land_pz)])
    check("西餐厨房、广场两个口的落点（%s、%s）能站、都在东边小路上（x ≥ 1400）" % [str(land_wk), str(land_pz)], lw._free(land_wk) and lw._free(land_pz) and land_wk.x >= 1400.0 and land_pz.x >= 1400.0)

    DirAccess.remove_absolute("user://test_fix_court.json")
    DirAccess.remove_absolute("user://test_fix_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
