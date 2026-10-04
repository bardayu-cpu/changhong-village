extends SceneTree
## 休息间第三版（lounge03 6385434）的走路测试（01 F 10/3 派，03 写）。不改游戏代码。
## 休息间 30 件家具挡人距离改成 6（跟化妆间一样，layout 里每件写 "clear": 6），样板按边距 6 摆的：从门口走得到每件跟前吗、有没有孤岛、窄道有哪些、摇杆直推歪推卡不卡。
##   1 休息间（x 336～672、y 226～684）能站的格子：从门口走不到的孤岛
##   2 每件写了 clear 的家具：4 边各取离占地 14 像素的点（能站的才算），至少一个从门口摇杆走得到；整件都走不到跟前的列出来
##   3 从后厅两个口、休息间门口，摇杆走到休息间每隔 24 像素一个的能站的点（卡住 2 秒算失败）；两个站人点、两个交互点
##   4 单格宽的窄道（拿掉这一格会隔断后面 ≥3 格）列出来；朝每处窄道隔出去的那块走，摇杆方向每 0.25 秒歪 0、25、45 度
##   5 摇杆直推：每处窄道里各取一格，从窄道一头直推到另一头（沿道的方向），起点 x 或 y 每隔 3 像素偏一偏，数出多宽的起点范围推得过去
## 用法：Godot --headless --path . --script res://tools/test_lounge03_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const STUCK_SECS := 2.0
const MAX_LEG := 90.0
# 10/4 方案 C：后厅四间整间平移（化妆间 +1195、休息室 +528、麻将室 −144），下面的坐标照平移后的写
const LOUNGE := Rect2(864, 226, 336, 458)

var m
var started := false
var ok := true
var b

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(560.0).timeout.connect(func():
        print("RESULT FAIL 560 秒没跑完（卡住了）")
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
    if m.state != "backhall":
        m._show_canvas("backhall")
        m._goto("backhall")
    b.walking_enabled = true
    b.stick = Vector2.ZERO

func walk(target: Vector2, wobble := 0.0) -> Dictionary:
    reenter()
    var path: Array = b.find_path(b.pos, target)
    if path.is_empty():
        return {"ok": false, "err": "寻路没路"}
    b.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - b.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        var dir: Vector2 = d.normalized()
        if wobble > 0.0:
            var sg: float = 1.0 if int(total / 0.25) % 2 == 0 else -1.0
            dir = dir.rotated(deg_to_rad(wobble) * sg * (0.4 if d.length() < 14.0 else 1.0))
        b.stick = dir
        b._process(DT)
        total += DT
        if m.state != "backhall":
            b.stick = Vector2.ZERO
            return {"ok": true, "secs": total, "exit_fired": true}
        var nd: float = (wp - b.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= STUCK_SECS or total > MAX_LEG:
            b.stick = Vector2.ZERO
            return {"ok": false, "err": "卡住", "at": b.pos, "wp": wp, "secs": total}
    b.stick = Vector2.ZERO
    return {"ok": true, "secs": total}

func cell_free(i: int, j: int) -> bool:
    return i >= 0 and j >= 0 and i < b.cols and j < b.rows and b.walk[j * b.cols + i] == 1

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

func cpos(c: Vector2i) -> Vector2:
    return Vector2((c.x + 0.5) * b.cell, (c.y + 0.5) * b.cell)

func in_lounge(c: Vector2i) -> bool:
    return LOUNGE.has_point(cpos(c))

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    b = m.backhall
    b.walking_enabled = true
    var t_start := Time.get_ticks_msec()

    var door: Vector2i = b._cell_of(Vector2(1032, 690))
    if not cell_free(door.x, door.y):
        door = b._nearest_free(door)
    var reach: Dictionary = flood(door)

    # ---- 1 孤岛 ----
    print("1 休息间孤岛")
    var free_n := 0
    var cut := 0
    for j in b.rows:
        for i in b.cols:
            if in_lounge(Vector2i(i, j)) and cell_free(i, j):
                free_n += 1
                if not reach.has(Vector2i(i, j)):
                    cut += 1
    print("    休息间能站的格子 %d 个，从门口走不到的 %d 个" % [free_n, cut])
    check("休息间没有孤岛", cut == 0)

    # ---- 2 每件跟前 ----
    print("2 每件家具跟前")
    var n_items := 0
    var no_front: Array = []
    var lounge_items: Array = []
    for it in b.cfg["items"]:
        if it.has("clear") and it.has("rect"):
            var r: Array = it["rect"]
            var rc := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
            if LOUNGE.intersects(rc):
                lounge_items.append(it)
    for it in lounge_items:
        n_items += 1
        var r: Array = it["rect"]
        var x0 := float(r[0])
        var y0 := float(r[1])
        var x1 := float(r[2])
        var y1 := float(r[3])
        var cands: Array = []
        for off in [14.0]:
            for t in range(0, 9):
                var fx := lerpf(x0, x1, t / 8.0)
                var fy := lerpf(y0, y1, t / 8.0)
                cands.append(Vector2(fx, y0 - off))
                cands.append(Vector2(fx, y1 + off))
                cands.append(Vector2(x0 - off, fy))
                cands.append(Vector2(x1 + off, fy))
        var found := false
        var any_free := false
        for c in cands:
            if not b._free(c):
                continue
            any_free = true
            if reach.has(b._cell_of(c)):
                found = true
                break
        if not found:
            # 放宽到 24 像素
            for t in range(0, 9):
                for c in [Vector2(lerpf(x0, x1, t / 8.0), y0 - 24.0), Vector2(lerpf(x0, x1, t / 8.0), y1 + 24.0), Vector2(x0 - 24.0, lerpf(y0, y1, t / 8.0)), Vector2(x1 + 24.0, lerpf(y0, y1, t / 8.0))]:
                    if b._free(c) and reach.has(b._cell_of(c)):
                        found = true
        if not found:
            no_front.append("%s %s" % [it["id"], str(it["rect"])])
    print("    写了 clear 的休息间家具 %d 件；离占地 14 像素（放宽到 24）的四周走不到跟前的：%s" % [n_items, str(no_front)])
    check("每件家具跟前都有能站、走得到的格子（%d 件）" % n_items, no_front.is_empty())

    # ---- 窄道 ----
    var chokes: Array = []
    for c in reach.keys():
        if not in_lounge(c):
            continue
        var r2: Dictionary = flood(door, c)
        var lost: int = reach.size() - 1 - r2.size()
        if lost >= 3:
            chokes.append({"cell": c, "lost": lost})
    print("    单格窄道（拿掉它会隔断 ≥3 格）：%d 处" % chokes.size())
    for ch in chokes:
        var c: Vector2i = ch["cell"]
        print("      格 (%d,%d) 画布 (%d,%d)：隔断 %d 格" % [c.x, c.y, int(cpos(c).x), int(cpos(c).y), ch["lost"]])

    # ---- 3 走遍 ----
    print("3 从门口走到每个点")
    var targets: Array = []
    for j in b.rows:
        for i in b.cols:
            var c := Vector2i(i, j)
            var cp := cpos(c)
            if in_lounge(c) and cell_free(i, j) and int(cp.x) % 24 < 12 and int(cp.y) % 24 < 12:
                targets.append(cp)
    var bad := 0
    var n_walk := 0
    var worst := 0.0
    for t in targets:
        reenter()
        b.reset_to(Vector2(1032, 690))
        var r := walk(t)
        n_walk += 1
        worst = maxf(worst, float(r.get("secs", 0.0)))
        if not (r["ok"] and ((b.pos - t).length() <= 14.0 or r.get("exit_fired", false))):
            bad += 1
            if bad <= 10:
                print("    不通：→ %s %s 站在 %s" % [str(t), str(r), str(b.pos)])
        if n_walk % 6 == 0:
            var r2 := walk(Vector2(1032, 690))
            n_walk += 1
            if not (r2["ok"] and (b.pos - Vector2(1032, 690)).length() <= 16.0):
                bad += 1
                print("    回不去：%s → 门口 %s 站在 %s" % [str(t), str(r2), str(b.pos)])
    print("    门口到休息间 %d 个点（含部分走回），共 %d 趟，最长一趟 %.1f 秒" % [targets.size(), n_walk, worst])
    check("门口到休息间每个点走得到、走得回来", bad == 0)
    var bad2 := 0
    for fk in [Vector2(1436, 780), Vector2(100, 780)]:
        for id in ["lounge"]:
            reenter()
            b.reset_to(fk)
            var r := walk(b.points[id]["pos"])
            if not (r["ok"] and ((b.pos - b.points[id]["pos"]).length() <= float(b.points[id]["r"]) or r.get("exit_fired", false))):
                bad2 += 1
                print("    不通：", fk, " → ", id, " ", r)
        for sp in b.cfg.get("stand_points", []):
            reenter()
            b.reset_to(fk)
            var tp := Vector2(float(sp["x"]), float(sp["y"]))
            if not b._free(tp):
                var nc: Vector2i = b._nearest_free(b._cell_of(tp))
                tp = cpos(nc)
            var r := walk(tp)
            var near: bool = (b.pos - Vector2(float(sp["x"]), float(sp["y"]))).length() <= float(sp["r"]) + 14.0
            print("    站人点 %s (%s,%s)：从 %s 走%s，站在 %s" % [sp["id"], sp["x"], sp["y"], str(fk), "到" if (r["ok"] and near) else "不到 " + str(r), str(b.pos)])
            if not (r["ok"] and near):
                bad2 += 1
    check("从宴会厅口、草坪口走到 lounge 点和两个站人点", bad2 == 0)

    # ---- 4 歪着走 ----
    print("4 摇杆歪着走到每处窄道隔出去的那块")
    var bad3 := 0
    var tried := 0
    for ch in chokes:
        var c: Vector2i = ch["cell"]
        var r2: Dictionary = flood(door, c)
        var far := Vector2.ZERO
        var best := -1.0
        for k in reach.keys():
            if not r2.has(k) and k != c:
                var d := cpos(k).distance_to(cpos(c))
                if d > best:
                    best = d
                    far = cpos(k)
        if best < 0.0:
            continue
        for wob in [0.0, 25.0, 45.0]:
            reenter()
            b.reset_to(Vector2(1032, 690))
            var r := walk(far, wob)
            tried += 1
            if not (r["ok"] and (b.pos - far).length() <= 14.0):
                bad3 += 1
                print("    卡：窄道 (%d,%d) → 里面 %s，摇杆歪 %.0f 度：%s 站在 %s" % [c.x, c.y, str(far), wob, str(r), str(b.pos)])
    print("    试了 %d 趟" % tried)
    check("歪着推摇杆走到窄道里面不卡", bad3 == 0)

    # ---- 5 直推 ----
    print("5 窄道里摇杆沿道直推：起点偏几像素还推得过去")
    var lanes: Array = []      # 每条窄道：连续的单格窄道格子（同一行或同一列），取头和尾
    var by_row := {}
    var by_col := {}
    for ch in chokes:
        var c: Vector2i = ch["cell"]
        by_row[c.y] = (by_row.get(c.y, []) as Array) + [c.x]
        by_col[c.x] = (by_col.get(c.x, []) as Array) + [c.y]
    for y in by_row:
        var xs: Array = by_row[y]
        xs.sort()
        var s := 0
        for k in range(1, xs.size() + 1):
            if k == xs.size() or xs[k] != xs[k - 1] + 1:
                if k - s >= 3:
                    lanes.append({"axis": "x", "fixed": y, "from": xs[s], "to": xs[k - 1]})
                s = k
    for x in by_col:
        var ys: Array = by_col[x]
        ys.sort()
        var s2 := 0
        for k in range(1, ys.size() + 1):
            if k == ys.size() or ys[k] != ys[k - 1] + 1:
                if k - s2 >= 3:
                    lanes.append({"axis": "y", "fixed": x, "from": ys[s2], "to": ys[k - 1]})
                s2 = k
    print("    连成一条的窄道（≥3 格长）%d 条" % lanes.size())
    var lane_bad := 0
    for ln in lanes:
        var ok_offs: Array = []
        var all_offs: Array = []
        for off in range(-9, 10, 3):
            var a: Vector2
            var z: Vector2
            if ln["axis"] == "x":
                var yy: float = (int(ln["fixed"]) + 0.5) * b.cell + off
                a = Vector2((int(ln["from"]) - 1) * b.cell + 6.0, yy)
                z = Vector2((int(ln["to"]) + 2) * b.cell, yy)
            else:
                var xx: float = (int(ln["fixed"]) + 0.5) * b.cell + off
                a = Vector2(xx, (int(ln["from"]) - 1) * b.cell + 6.0)
                z = Vector2(xx, (int(ln["to"]) + 2) * b.cell)
            if not (b._free(a) and b._free(z)):
                continue
            all_offs.append(off)
            reenter()
            b.reset_to(a)
            b.path.clear()
            var best_d := INF
            var noprog := 0.0
            var total := 0.0
            var fail := false
            while (z - b.pos).length() > 3.0:
                b.stick = (z - b.pos).normalized()
                b._process(DT)
                total += DT
                var nd: float = (z - b.pos).length()
                if nd < best_d - 0.3:
                    best_d = nd
                    noprog = 0.0
                else:
                    noprog += DT
                if noprog >= 1.0 or total > 20.0:
                    fail = true
                    break
            b.stick = Vector2.ZERO
            if not fail:
                ok_offs.append(off)
        print("    窄道 %s 向 固定第 %d 格，第 %d～%d 格：偏 %s 像素的起点里推得过去的 %s" % ["横" if ln["axis"] == "x" else "竖", ln["fixed"], ln["from"], ln["to"], str(all_offs), str(ok_offs)])
        if all_offs.size() > 0 and ok_offs.is_empty():
            lane_bad += 1
    check("每条窄道至少有一种起点偏法能直推走完（没有整条推不过去的）", lane_bad == 0)
    print("  共 %.1f 秒" % ((Time.get_ticks_msec() - t_start) / 1000.0))
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
