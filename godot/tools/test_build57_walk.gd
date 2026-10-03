extends SceneTree
## 第 57 版（build57 bd139d9，码从 f06fe3c 导出）的走路测试（01 F 10/3 派，03 写）。不改游戏代码；存档指到临时文件。
## 四块：麻将室所在的后厅、草坪、停车场、湖边（3072 宽长湖岸）。照玩家推摇杆那样一步步走（同 test_hall55_walk.gd 的走法），卡住 2 秒算失败。
##   1 孤岛：走路范围里没被占地挡、却被圈掉不能站的格子
##   2 每块从各出入口走到每个能站的点（每隔 48 像素取一个）和每个交互点（进到半径里）、再抽样走回；走进出口半径会切场景，算到了
##   3 后厅麻将室（x 672～1008）每件家具四周 14 像素（放宽到 24）至少有一个走得到的格子；单格窄道清单
##   4 湖边整条从东到西：东头月亮门进门处 → 西头月亮门（去停车场）→ 走回；两个方向的时间
##   5 停车场：自己的车 → 门楼门洞（进迎宾院）、→ 路东月亮门（去湖边）；湖边西头 ↔ 停车场
## 用法：Godot --headless --path . --script res://tools/test_build57_walk.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ent = preload("res://scripts/entrance.gd")
const DT := 1.0 / 60.0
const STUCK_SECS := 2.0
const MAX_LEG := 240.0
const CANVASES := ["parking", "lake", "lawn", "backhall"]
const MJ := Rect2(672, 226, 336, 458)
## 03 测第 57 版时已报给 01 的已知现状（回执 测-build57.md）：这些圈掉的格子数、走不到跟前的件不算新问题，只守「不再多」
const KNOWN_POCKETS := {"lawn": 6, "backhall": 84}
const KNOWN_NO_FRONT := ["mj2_chair_n", "mj_stand_2"]

var m
var started := false
var ok := true
var cv                      # 现在测的这块画布
var cname := ""

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(580.0).timeout.connect(func():
        print("RESULT FAIL 580 秒没跑完（卡住了）")
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

func reenter() -> void:
    m.switching = false
    if m.state != cname:
        m._show_canvas(cname)
        m._goto(cname)
    cv.walking_enabled = true
    cv.stick = Vector2.ZERO

func walk(target: Vector2) -> Dictionary:
    reenter()
    var path: Array = cv.find_path(cv.pos, target)
    if path.is_empty():
        return {"ok": false, "err": "寻路没路"}
    cv.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - cv.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        cv.stick = d.normalized()
        cv._process(DT)
        total += DT
        if m.state != cname:
            cv.stick = Vector2.ZERO
            return {"ok": true, "secs": total, "exit_fired": true}
        var nd: float = (wp - cv.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= STUCK_SECS or total > MAX_LEG:
            cv.stick = Vector2.ZERO
            return {"ok": false, "err": "卡住", "at": cv.pos, "wp": wp, "secs": total}
    cv.stick = Vector2.ZERO
    return {"ok": true, "secs": total}

func cell_free(i: int, j: int) -> bool:
    return i >= 0 and j >= 0 and i < cv.cols and j < cv.rows and cv.walk[j * cv.cols + i] == 1

func cpos(c: Vector2i) -> Vector2:
    return Vector2((c.x + 0.5) * cv.cell, (c.y + 0.5) * cv.cell)

func flood(start: Vector2i, removed := Vector2i(-1, -1)) -> Dictionary:
    var seen := {start: true}
    var st: Array = [start]
    while not st.is_empty():
        var c: Vector2i = st.pop_back()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var n: Vector2i = c + d
            if n == removed or seen.has(n) or not cell_free(n.x, n.y):
                continue
            seen[n] = true
            st.append(n)
    return seen

func canvas_of(name: String):
    return {"parking": m.parking, "lake": m.lake, "lawn": m.lawn, "backhall": m.backhall}[name]

func starts_of() -> Dictionary:
    var out := {"出生/进场点": Vector2(float(cv.cfg["spawn"][0]), float(cv.cfg["spawn"][1]))}
    for k in ["from_court", "from_lake", "from_parking"]:
        if cv.cfg.has(k):
            out[k] = Vector2(float(cv.cfg[k][0]), float(cv.cfg[k][1]))
    if cname == "backhall":
        out["草坪口"] = Vector2(1440, 780)
    if cname == "lawn":
        out["迎宾院口"] = Vector2(100, 780)
        out["后厅口"] = Vector2(100, 300)
        out["果园口"] = Vector2(768, 200)
    return out

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_b57_court.json"
    m.games_save.local_path = "user://test_b57_games.json"
    for cn in CANVASES:
        m.ensure_canvas(cn)
    var t_start := Time.get_ticks_msec()
    for cn in CANVASES:
        cname = cn
        cv = canvas_of(cn)
        m._show_canvas(cn)
        m._goto(cn)
        cv.walking_enabled = true
        print("== %s（画布 %s）" % [cn, str(cv.cfg["size"])])
        # 1 孤岛
        var polys: Array = []
        for poly in cv.cfg["walk"]:
            var pts := PackedVector2Array()
            for v in poly:
                pts.append(Vector2(float(v[0]), float(v[1])))
            polys.append(pts)
        var pockets: Array = []
        var free_n := 0
        for j in cv.rows:
            for i in cv.cols:
                var cp := cpos(Vector2i(i, j))
                if cell_free(i, j):
                    free_n += 1
                    continue
                var inside := false
                for pts in polys:
                    if Geometry2D.is_point_in_polygon(cp, pts):
                        inside = true
                if inside and not Ent._blocked(cp.x, cp.y, cv.obstacles, Ent.CLEAR):
                    pockets.append(cp)
        print("  能站的格子 %d 个（每格 %d）；走路范围里没被占地挡、却被圈掉的 %d 格 %s" % [free_n, int(cv.cell), pockets.size(), str(pockets.slice(0, 5))])
        # 圈掉的格子连成几块，各块的范围
        var left: Dictionary = {}
        for pp in pockets:
            left[Vector2i(int(pp.x / cv.cell), int(pp.y / cv.cell))] = true
        var comps: Array = []
        while not left.is_empty():
            var seed: Vector2i = left.keys()[0]
            var stack: Array = [seed]
            left.erase(seed)
            var bb := Rect2(cpos(seed) - Vector2(6, 6), Vector2(12, 12))
            var cnt := 1
            while not stack.is_empty():
                var c: Vector2i = stack.pop_back()
                for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                    var n: Vector2i = c + d
                    if left.has(n):
                        left.erase(n)
                        stack.append(n)
                        bb = bb.merge(Rect2(cpos(n) - Vector2(6, 6), Vector2(12, 12)))
                        cnt += 1
            comps.append("%d 格 x %d～%d、y %d～%d" % [cnt, int(bb.position.x), int(bb.end.x), int(bb.position.y), int(bb.end.y)])
        if comps.size() > 0:
            print("  圈掉的格子连成 %d 块：%s" % [comps.size(), str(comps)])
        check("%s 圈掉的格子 %d 个，不比已知的 %d 个多" % [cn, pockets.size(), int(KNOWN_POCKETS.get(cn, 0))], pockets.size() <= int(KNOWN_POCKETS.get(cn, 0)))
        # 2 走遍
        var starts := starts_of()
        var targets: Array = []
        for j in cv.rows:
            for i in cv.cols:
                var cp := cpos(Vector2i(i, j))
                if cell_free(i, j) and int(cp.x) % 48 < 12 and int(cp.y) % 48 < 12:
                    targets.append(cp)
        var bad := 0
        var n_walk := 0
        var worst := 0.0
        for sk in starts:
            var sp: Vector2 = starts[sk]
            if not cv._free(sp):
                sp = cpos(cv._nearest_free(cv._cell_of(sp)))
            for t in targets:
                reenter()
                cv.reset_to(sp)
                var r := walk(t)
                n_walk += 1
                worst = maxf(worst, float(r.get("secs", 0.0)))
                if not (r["ok"] and ((cv.pos - t).length() <= 14.0 or r.get("exit_fired", false))):
                    bad += 1
                    if bad <= 8:
                        print("    不通：%s %s → %s %s 站在 %s" % [sk, str(sp), str(t), str(r), str(cv.pos)])
                if n_walk % 10 == 0:
                    var r2 := walk(sp)
                    n_walk += 1
                    if not (r2["ok"] and ((cv.pos - sp).length() <= 16.0 or r2.get("exit_fired", false))):
                        bad += 1
                        print("    回不去：%s → %s %s 站在 %s" % [str(t), str(sp), str(r2), str(cv.pos)])
        print("  %d 个出入口起点 × %d 个点，共 %d 趟，最长一趟 %.1f 秒" % [starts.size(), targets.size(), n_walk, worst])
        check("%s 从每个出入口走到每个能站的点、抽样走得回来" % cn, bad == 0)
        var bad2 := 0
        for id in cv.points:
            var pt: Vector2 = cv.points[id]["pos"]
            for sk in starts:
                var sp: Vector2 = starts[sk]
                if not cv._free(sp):
                    sp = cpos(cv._nearest_free(cv._cell_of(sp)))
                if sp.distance_to(pt) < float(cv.points[id]["r"]) + 20.0:
                    continue    # 起点就在这个点的半径里
                reenter()
                cv.reset_to(sp)
                var r := walk(pt)
                var near: bool = (cv.pos - pt).length() <= float(cv.points[id]["r"]) or r.get("exit_fired", false)
                if not (r["ok"] and near):
                    bad2 += 1
                    print("    交互点不通：%s → %s %s" % [sk, id, str(r)])
        check("%s 每个交互点（%s）从各出入口都走得到" % [cn, str(cv.points.keys())], bad2 == 0)
        # 3 麻将室
        if cn == "backhall":
            var door: Vector2i = cv._cell_of(Vector2(840, 690))
            if not cell_free(door.x, door.y):
                door = cv._nearest_free(door)
            var reach: Dictionary = flood(door)
            var items_n := 0
            var no_front: Array = []
            for it in cv.cfg["items"]:
                if not it.has("rect"):
                    continue
                var r: Array = it["rect"]
                var rc := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
                if not MJ.intersects(rc) or str(it["id"]).begins_with("wall_") or str(it["id"]).begins_with("front_"):
                    continue
                items_n += 1
                var found := false
                for off in [14.0, 24.0]:
                    for t in range(0, 9):
                        var fx := lerpf(rc.position.x, rc.end.x, t / 8.0)
                        var fy := lerpf(rc.position.y, rc.end.y, t / 8.0)
                        for c in [Vector2(fx, rc.position.y - off), Vector2(fx, rc.end.y + off), Vector2(rc.position.x - off, fy), Vector2(rc.end.x + off, fy)]:
                            if cv._free(c) and reach.has(cv._cell_of(c)):
                                found = true
                    if found:
                        break
                if not found:
                    no_front.append("%s %s" % [it["id"], str(it["rect"])])
            print("  麻将室家具 %d 件；四周 14（放宽 24）像素走不到跟前的：%s" % [items_n, str(no_front)])
            var new_bad: Array = no_front.filter(func(x): return not KNOWN_NO_FRONT.any(func(k): return str(x).begins_with(k)))
            check("麻将室每件家具跟前走得到（%d 件；已知走不到跟前的 %s 不算，新的 %s）" % [items_n, str(KNOWN_NO_FRONT), str(new_bad)], new_bad.is_empty())
            var chokes: Array = []
            for c in reach.keys():
                if not MJ.has_point(cpos(c)):
                    continue
                var lost: int = reach.size() - 1 - flood(door, c).size()
                if lost >= 3:
                    chokes.append([int(cpos(c).x), int(cpos(c).y), lost])
            print("  麻将室单格窄道（拿掉会隔断 ≥3 格）%d 处：%s" % [chokes.size(), str(chokes.slice(0, 16))])
    # 4 湖边整条
    print("== 湖边整条从东到西")
    cname = "lake"
    cv = m.lake
    var east := Vector2(2304, 1140)
    var west_exit: Vector2 = cv.points["to_parking"]["pos"]
    reenter()
    cv.reset_to(east)
    var rw := walk(west_exit)
    print("  东头月亮门进门处 %s → 西头出口 %s：%s，站在 %s" % [str(east), str(west_exit), str(rw), str(cv.pos)])
    check("湖边东到西走得通（走进西头月亮门的半径里就切去停车场）", rw["ok"] and (rw.get("exit_fired", false) or (cv.pos - west_exit).length() <= 36.0))
    reenter()
    cv.reset_to(Vector2(740, 1140))
    var re := walk(Vector2(2304, 1226))
    print("  西头 (740,1140) → 东头出口 (2304,1226)：%s，站在 %s" % [str(re), str(cv.pos)])
    check("湖边西到东走得通", re["ok"] and (re.get("exit_fired", false) or (cv.pos - Vector2(2304, 1226)).length() <= 36.0))
    for pt in ["pavilion", "bench"]:
        reenter()
        cv.reset_to(east)
        var r1 := walk(cv.points[pt]["pos"])
        reenter()
        var r2 := walk(Vector2(740, 1140))
        print("  东头 → %s：%.1f 秒；再走到西头：%.1f 秒（%s）" % [pt, float(r1.get("secs", 0.0)), float(r2.get("secs", 0.0)), str(r2["ok"])])
        check("东头走到 %s 再走到西头" % pt, r1["ok"] and r2["ok"])
    # 5 停车场
    print("== 停车场")
    cname = "parking"
    cv = m.parking
    var pairs := [["my_car", "to_court"], ["my_car", "to_lake"], ["to_court", "my_car"], ["to_lake", "my_car"]]
    var pbad := 0
    for pr in pairs:
        reenter()
        var a: Vector2 = cv.points[pr[0]]["pos"]
        cv.reset_to(a)
        var r := walk(cv.points[pr[1]]["pos"])
        var near: bool = (cv.pos - cv.points[pr[1]]["pos"]).length() <= float(cv.points[pr[1]]["r"]) or r.get("exit_fired", false)
        print("  %s → %s：%s" % [pr[0], pr[1], str(r)])
        if not (r["ok"] and near):
            pbad += 1
    check("停车场：车、门楼、湖边月亮门之间走得通", pbad == 0)
    print("  共 %.1f 秒" % ((Time.get_ticks_msec() - t_start) / 1000.0))
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
