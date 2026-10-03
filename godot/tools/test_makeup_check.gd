extends SceneTree
## 化妆间进游戏（makeup01-02d 81c5354，化妆间 + 休息间一起）的走路测试（01 F 10/3 派，03 写）。不改游戏代码。
## 化妆间 32 件 mk_ 的挡人距离从 12 改成 6（entrance.gd 每件可写 clear），首饰中岛两边的道只剩一格宽（12 像素）：人走得过去吗、摇杆卡不卡。
##   1 替身：新娘、两位化妆师（standin）都画上了、脚点不在任何家具的框里、跟最近家具的距离、新娘坐的凳子对不对
##   2 从后厅两个口、化妆间门口、休息间门口走到化妆间 / 休息间每个区（房间里每隔 24 像素的能站的点，摇杆照寻路走，卡住 2 秒算失败）；化妆间的点再走回门口
##   3 格子：化妆间、休息间里「没被家具挡、也没被走路范围挡」却走不到的孤岛；单格窄道（拿掉这一格就把别的格子隔断的）有哪些、隔断多大一块
##   4 摇杆歪着走：朝每处窄道隔出去的那块走，摇杆方向每 0.25 秒左右歪 25 度，卡住 2 秒算失败
##   5 首饰中岛两边的道：直着穿一趟（两个方向）
## 用法：Godot --headless --path . --script res://tools/test_makeup_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ent = preload("res://scripts/entrance.gd")
const DT := 1.0 / 60.0
const STUCK_SECS := 2.0
const MAX_LEG := 90.0
const MAKEUP := Rect2(0, 226, 336, 458)
const LOUNGE := Rect2(336, 226, 336, 458)

var m
var started := false
var ok := true
var b
var warn_lines: Array = []

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(600.0).timeout.connect(func():
        print("RESULT FAIL 600 秒没跑完（卡住了）")
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

## 摇杆走到 target。wobble > 0：摇杆方向每 0.25 秒左右在 ±wobble 度之间歪。回 {ok, secs, at}
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
            var sign_: float = 1.0 if int(total / 0.25) % 2 == 0 else -1.0
            dir = dir.rotated(deg_to_rad(wobble) * sign_ * (0.4 if d.length() < 14.0 else 1.0))
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

func in_room(room: Rect2, i: int, j: int) -> bool:
    return room.has_point(Vector2((i + 0.5) * b.cell, (j + 0.5) * b.cell))

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

    # ---- 1 替身 ----
    print("1 替身")
    var items := {}
    for it in b.cfg["items"]:
        items[str(it["id"])] = it
    var rects: Array = []
    for it in b.cfg["items"]:
        if str(it["id"]).begins_with("mk_") and it.has("rect"):
            rects.append({"id": str(it["id"]), "r": it["rect"]})
    for id in ["bride", "makeup_1", "makeup_2"]:
        var nd = b.npc_nodes.get(id)
        check("%s 画上了（替身：图的一块区域，不是代码小人）" % id, nd is Sprite2D and (nd as Sprite2D).region_enabled and not (nd as Sprite2D).centered)
        var at := Vector2.ZERO
        for n in b.cfg["npcs"]:
            if str(n["id"]) == id:
                at = Vector2(float(n["x"]), float(n["y"]))
        var inside := ""
        var nearest := INF
        var nearest_id := ""
        for e in rects:
            var r: Array = e["r"]
            var dx: float = maxf(maxf(float(r[0]) - at.x, at.x - float(r[2])), 0.0)
            var dy: float = maxf(maxf(float(r[1]) - at.y, at.y - float(r[3])), 0.0)
            var dd: float = sqrt(dx * dx + dy * dy)
            if dd < nearest:
                nearest = dd
                nearest_id = e["id"]
            if dd == 0.0:
                inside += e["id"] + " "
        print("    %s 脚点 %s：落在这些家具的占地里「%s」，离最近的 %s 占地 %.0f 像素" % [id, str(at), inside, nearest_id, nearest])
        if id != "bride":
            check("%s 脚点不在家具占地里" % id, inside == "")
    var stool: Array = items["mk_stool_2"]["rect"]
    var bride_at: Vector2 = Vector2.ZERO
    for n in b.cfg["npcs"]:
        if str(n["id"]) == "bride":
            bride_at = Vector2(float(n["x"]), float(n["y"]))
    check("新娘坐在中间那张凳子上（脚点 x 在凳面 %.0f～%.0f 里，y 不超出凳面往下 3 像素：%s）" % [stool[0], stool[2], str(bride_at)],
        bride_at.x >= float(stool[0]) and bride_at.x <= float(stool[2]) and bride_at.y >= float(stool[1]) and bride_at.y <= float(stool[3]) + 3.0)

    # ---- 3 格子 ----
    print("3 格子")
    var door_c: Vector2i = b._cell_of(Vector2(168, 690))
    var door_l: Vector2i = b._cell_of(Vector2(504, 690))
    if not cell_free(door_c.x, door_c.y):
        door_c = b._nearest_free(door_c)
    if not cell_free(door_l.x, door_l.y):
        door_l = b._nearest_free(door_l)
    var reach_c: Dictionary = flood(door_c)
    var reach_l: Dictionary = flood(door_l)
    for pair in [["化妆间", MAKEUP, reach_c], ["休息间", LOUNGE, reach_l]]:
        var room: Rect2 = pair[1]
        var reach: Dictionary = pair[2]
        var free_n := 0
        var cut := 0
        var pockets := 0
        for j in b.rows:
            for i in b.cols:
                if not in_room(room, i, j):
                    continue
                if cell_free(i, j):
                    free_n += 1
                    if not reach.has(Vector2i(i, j)):
                        cut += 1
        print("    %s：能站的格子 %d 个，从门口走不到的 %d 个" % [pair[0], free_n, cut])
        check("%s 没有孤岛（能站却走不到）" % pair[0], cut == 0)
    # 单格窄道：拿掉这一格，门口连着的格子少多少
    var chokes: Array = []
    var base_n: int = reach_c.size()
    for c in reach_c.keys():
        if not in_room(MAKEUP, c.x, c.y):
            continue
        var r2: Dictionary = flood(door_c, c)
        var lost: int = base_n - 1 - r2.size()
        if lost >= 3:
            chokes.append({"cell": c, "lost": lost})
    print("    化妆间单格窄道（拿掉它会隔断 ≥3 格）：%d 处" % chokes.size())
    var cut_cells: Dictionary = {}
    for ch in chokes:
        var c: Vector2i = ch["cell"]
        print("      格 (%d,%d) 画布 (%d,%d)：隔断 %d 格" % [c.x, c.y, int((c.x + 0.5) * b.cell), int((c.y + 0.5) * b.cell), ch["lost"]])
    var b2_chokes: Array = []
    for c in reach_l.keys():
        if not in_room(LOUNGE, c.x, c.y):
            continue
        var r3: Dictionary = flood(door_l, c)
        var lost2: int = reach_l.size() - 1 - r3.size()
        if lost2 >= 3:
            b2_chokes.append({"cell": c, "lost": lost2})
    print("    休息间单格窄道（拿掉它会隔断 ≥3 格）：%d 处" % b2_chokes.size())
    for ch in b2_chokes:
        var c: Vector2i = ch["cell"]
        print("      格 (%d,%d) 画布 (%d,%d)：隔断 %d 格" % [c.x, c.y, int((c.x + 0.5) * b.cell), int((c.y + 0.5) * b.cell), ch["lost"]])

    # ---- 2 走遍 ----
    print("2 从门口走到每个区")
    var bad := 0
    var n_walk := 0
    var worst := 0.0
    var targets: Array = []
    for j in b.rows:
        for i in b.cols:
            var cp := Vector2((i + 0.5) * b.cell, (j + 0.5) * b.cell)
            if (MAKEUP.has_point(cp) or LOUNGE.has_point(cp)) and cell_free(i, j) and int(cp.x) % 24 < 12 and int(cp.y) % 24 < 12:
                targets.append(cp)
    for t in targets:
        for door in [Vector2(168, 690), Vector2(504, 690)]:
            if (MAKEUP.has_point(t) and door.x > 300) or (LOUNGE.has_point(t) and door.x < 300):
                continue
            reenter()
            b.reset_to(door)
            var r := walk(t)
            n_walk += 1
            worst = maxf(worst, float(r.get("secs", 0.0)))
            var arrived: bool = (b.pos - t).length() <= 14.0 or r.get("exit_fired", false)
            if not (r["ok"] and arrived):
                bad += 1
                if bad <= 12:
                    print("    不通：%s → %s %s 站在 %s" % [str(door), str(t), str(r), str(b.pos)])
            # 化妆间的点走回门口
            if MAKEUP.has_point(t) and n_walk % 5 == 0:
                var r2 := walk(door)
                n_walk += 1
                if not (r2["ok"] and (b.pos - door).length() <= 14.0):
                    bad += 1
                    print("    回不去：%s → %s %s 站在 %s" % [str(t), str(door), str(r2), str(b.pos)])
    print("    走了 %d 趟（化妆间、休息间各 %d、%d 个点），最长一趟 %.1f 秒" % [n_walk, targets.filter(func(p): return MAKEUP.has_point(p)).size(), targets.filter(func(p): return LOUNGE.has_point(p)).size(), worst])
    check("从门口走到两间每个点、化妆间的点走得回来（不卡住、到得了）", bad == 0)
    # 从后厅两个口走到两个房间
    var bad2 := 0
    for fk in [Vector2(100, 780), Vector2(1440, 780)]:
        for t0 in [Vector2(168, 400), Vector2(504, 420), Vector2(60, 300), Vector2(160, 520), Vector2(300, 640)]:
            var t: Vector2 = t0
            if not b._free(t):    # 点在家具占地里：换成最近能站的格子
                var nc: Vector2i = b._nearest_free(b._cell_of(t))
                t = Vector2((nc.x + 0.5) * b.cell, (nc.y + 0.5) * b.cell)
            reenter()
            b.reset_to(fk)
            var r := walk(t)
            if not (r["ok"] and ((b.pos - t).length() <= 20.0 or r.get("exit_fired", false))):
                bad2 += 1
                print("    不通：", fk, " → ", t, " ", r)
    check("从宴会厅口、草坪口走进两间房 10 条路都通", bad2 == 0)

    # ---- 4 歪着走 ----
    print("4 摇杆歪着走到每处窄道隔出去的那块")
    var bad3 := 0
    var tried := 0
    for ch in chokes:
        var c: Vector2i = ch["cell"]
        var r2: Dictionary = flood(door_c, c)
        # 被隔出去的格子里挑离窄道最远的一个
        var far := Vector2.ZERO
        var best := -1.0
        for k in reach_c.keys():
            if not r2.has(k) and k != c:
                var p := Vector2((k.x + 0.5) * b.cell, (k.y + 0.5) * b.cell)
                var d: float = p.distance_to(Vector2((c.x + 0.5) * b.cell, (c.y + 0.5) * b.cell))
                if d > best:
                    best = d
                    far = p
        if best < 0.0:
            continue
        for wob in [0.0, 25.0, 45.0]:
            reenter()
            b.reset_to(Vector2(168, 690))
            var r := walk(far, wob)
            tried += 1
            if not (r["ok"] and (b.pos - far).length() <= 14.0):
                bad3 += 1
                print("    卡：窄道 (%d,%d) → 里面 %s，摇杆歪 %.0f 度：%s 站在 %s" % [c.x, c.y, str(far), wob, str(r), str(b.pos)])
    print("    试了 %d 趟" % tried)
    check("歪着推摇杆走到窄道里面不卡", bad3 == 0)

    # ---- 5 首饰中岛两边 ----
    print("5 首饰中岛 mk_island 两边的道")
    var isl: Array = items["mk_island"]["rect"]
    var isl_free_w := 0
    var isl_free_e := 0
    for j in b.rows:
        for i in b.cols:
            var cp := Vector2((i + 0.5) * b.cell, (j + 0.5) * b.cell)
            if cp.y > float(isl[1]) - 6.0 and cp.y < float(isl[3]) + 6.0 and cell_free(i, j):
                if cp.x < float(isl[0]) and cp.x > float(isl[0]) - 40.0:
                    isl_free_w += 1
                    print("      西边能站的格 画布 (%d,%d)" % [int(cp.x), int(cp.y)])
                if cp.x > float(isl[2]) and cp.x < float(isl[2]) + 40.0:
                    isl_free_e += 1
                    print("      东边能站的格 画布 (%d,%d)" % [int(cp.x), int(cp.y)])
    print("    岛占地 %s（clear 6）：西边 40 像素内能站的格 %d、东边 %d" % [str(isl), isl_free_w, isl_free_e])
    # 岛本身占 x 138～198（clear 6），道是西边 x 120～132 那一列和东边 x 204～216 那一列（各一格宽 12）。
    # 从 y=486 那条横道（岛北边）往南直着推摇杆，起点 x 每隔 3 像素试一次：多宽的起点范围推得过去（到 y=545）
    var lane_ok := {}
    var lane_diag := {}
    for x0 in range(102, 234, 3):
        var a := Vector2(float(x0), 486.0)
        if not b._free(a):
            continue
        for tilt in [0.0, 0.5, -0.5]:
            reenter()
            b.reset_to(a)
            b.path.clear()
            var best_y := -INF
            var noprog := 0.0
            var total := 0.0
            var fail := false
            while b.pos.y < 528.0:
                b.stick = Vector2(tilt, 1.0).normalized()
                b._process(DT)
                total += DT
                if b.pos.y > best_y + 0.3:
                    best_y = b.pos.y
                    noprog = 0.0
                else:
                    noprog += DT
                if noprog >= 1.0 or total > 15.0:
                    fail = true
                    break
            b.stick = Vector2.ZERO
            if tilt == 0.0:
                lane_ok[x0] = not fail
            elif not fail:
                lane_diag[x0] = true
    var okx := []
    var badx := []
    for x0 in lane_ok:
        (okx if lane_ok[x0] else badx).append(x0)
    var west_ok := okx.filter(func(v): return v < 170)
    var east_ok := okx.filter(func(v): return v >= 170)
    print("    从岛北边横道 y=486 往南直推摇杆（起点 x 每隔 3 像素，推到 y=528）：")
    print("      西边那列（x 120～132）推得过去的起点 x = %s" % str(west_ok))
    print("      东边那列（x 204～216）推得过去的起点 x = %s" % str(east_ok))
    print("      顶住不动的起点 x = %s" % str(badx))
    print("      歪一点推（摇杆带 ±27 度）也推得过去的起点 x = %s" % str(lane_diag.keys()))
    check("岛两边的列各有起点能直着推过去", west_ok.size() > 0 and east_ok.size() > 0)
    # 点地走：从岛北边走到岛南边（点两边）
    var tap_bad := 0
    for pair in [[Vector2(126, 486), Vector2(126, 545)], [Vector2(210, 486), Vector2(210, 530)], [Vector2(100, 486), Vector2(240, 545)], [Vector2(240, 486), Vector2(100, 545)]]:
        reenter()
        b.reset_to(pair[0])
        var r := walk(pair[1])
        print("    点地走 %s → %s：%s，站在 %s" % [str(pair[0]), str(pair[1]), str(r), str(b.pos)])
        if not r["ok"]:
            tap_bad += 1
    check("岛两边的道点地走（寻路）走得过", tap_bad == 0)
    print("  共 %.1f 秒" % ((Time.get_ticks_msec() - t_start) / 1000.0))
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
