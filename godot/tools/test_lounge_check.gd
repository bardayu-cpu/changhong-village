extends SceneTree
## 休息间进游戏（lounge01 4406d23）的走路测试（01 E 10/3 派，03 写）：新占地琴叶榕 [497,234,515,242]、衣帽架 [648,598,666,606] 会不会卡住人，
## 唱片机前那块站人的地站不站得进去，后厅所有出入口、四个房间、厨房走得通。照玩家推摇杆那样一步步走（同 test_hall55_walk.gd 的走法），不改游戏代码。
##   1 从进后厅的两个口（宴会厅来 (100,780)、草坪来 (1440,780)）摇杆走到每个交互点、两个出口、唱片机前 (424,320)，卡住 2 秒算失败
##   2 新占地到底多挡了哪些格子：拿现在的格子跟「去掉这两块占地」重算的比，多出来的格子数、范围；有没有因为它们让别的格子走不到了（flood 掉的）
##   3 琴叶榕、衣帽架四周各 12 个方向、离占地 14～40 像素站着，朝占地推摇杆走 2 秒再朝外走 1 秒：不能被带进占地、朝外要走得开
##   4 唱片机前 (424,320)：站得进去、旁边 56×60 里能站的格子数、最大空地
##   5 休息间里所有能走的格子：从 lounge 点出发都到得了（没有被新占地圈出去的孤岛）
## 用法：Godot --headless --path . --script res://tools/test_lounge_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ent = preload("res://scripts/entrance.gd")
const DT := 1.0 / 60.0
const STUCK_SECS := 2.0
const MAX_LEG := 120.0
const FIG := [497.0, 234.0, 515.0, 242.0]
var RACK: Array = [648.0, 598.0, 666.0, 606.0]   # 第一版在东南角；10/3 第三版挪到门洞东边，run() 开头照 layout 取
const LOUNGE := Rect2(336, 226, 336, 458)   # 休息间两道隔墙之间

var m
var started := false
var ok := true
var b

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(300.0).timeout.connect(func():
        print("RESULT FAIL 300 秒没跑完（卡住了）")
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

## 走进出口的半径会切场景（main 的 spot 信号），切走以后摇杆就不动了：每次开走前先回到后厅、重新开走路
func reenter() -> void:
    if m.state != "backhall":
        m._show_canvas("backhall")
        m._goto("backhall")
    b.walking_enabled = true
    b.stick = Vector2.ZERO

func stick_walk(target: Vector2) -> Dictionary:
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
        b.stick = d.normalized()
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

func grid_rows(obs: Array) -> Array:
    return Ent.compute_grid(b.cfg, obs, Ent.GRID_CELL, Ent.CLEAR)["rows"]

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
    for it in b.cfg["items"]:
        if str(it.get("id", "")) == "coat_rack":
            RACK = (it["rect"] as Array).map(func(v): return float(v))
    var t_start := Time.get_ticks_msec()
    print("0 布局：像素图 %s、灰盒 琴叶榕/衣帽架 占地在 %s" % [str(b.cfg.has("pixel_art")), "obstacles"])
    check("布局写了 pixel_art", b.cfg.has("pixel_art"))
    var fig_ob := -1
    var rack_ob := -1
    for i in b.obstacles.size():
        var o: Dictionary = b.obstacles[i]
        if o.has("rect"):
            var r: Array = o["rect"]
            if is_equal_approx(r[0], FIG[0]) and is_equal_approx(r[1], FIG[1]) and is_equal_approx(r[2], FIG[2]) and is_equal_approx(r[3], FIG[3]):
                fig_ob = i
            if is_equal_approx(r[0], RACK[0]) and is_equal_approx(r[1], RACK[1]) and is_equal_approx(r[2], RACK[2]) and is_equal_approx(r[3], RACK[3]):
                rack_ob = i
    check("琴叶榕、衣帽架的占地都在挡人的占地里", fig_ob >= 0 and rack_ob >= 0)

    # 1 走通
    print("1 从两个进口走到每个点（摇杆）")
    var targets := {}
    for id in b.points:
        targets[id] = (b.points[id]["pos"] as Vector2)
    targets["record_front"] = Vector2(424, 320)
    var from_pts := {"宴会厅口": Vector2(100, 780), "草坪口": Vector2(1440, 780)}
    var bad := 0
    for fk in from_pts:
        for id in targets:
            b.reset_to(from_pts[fk])
            var r := stick_walk(targets[id])
            var want_r := 12.0
            if id != "record_front" and b.points.has(id):
                want_r = float(b.points[id]["r"])
            var arrived: bool = (b.pos - targets[id]).length() <= want_r or r.get("exit_fired", false)
            if not (r["ok"] and arrived):
                bad += 1
                print("    不通：", fk, " → ", id, " ", r, " 站在 ", b.pos)
    check("两个口 × %d 个目标都走得到（不卡住、到得了半径里）" % targets.size(), bad == 0)

    # 2 新占地多挡的格子
    print("2 新占地多挡了哪些格子")
    var obs_wo: Array = []
    for i in b.obstacles.size():
        if i != fig_ob and i != rack_ob:
            obs_wo.append(b.obstacles[i])
    var old_rows: Array = grid_rows(obs_wo)
    var new_rows: Array = b.cfg["walk_grid"]["rows"]
    var lost := []
    var gained := []
    for j in new_rows.size():
        var a: String = old_rows[j]
        var c: String = new_rows[j]
        for i in c.length():
            if a.unicode_at(i) == 49 and c.unicode_at(i) != 49:
                lost.append(Vector2i(i, j))
            elif a.unicode_at(i) != 49 and c.unicode_at(i) == 49:
                gained.append(Vector2i(i, j))
    var cell: int = Ent.GRID_CELL
    var near_only := true
    var far_cells := []
    for v in lost:
        var cx: float = (v.x + 0.5) * cell
        var cy: float = (v.y + 0.5) * cell
        var near_fig: bool = cx > FIG[0] - Ent.CLEAR - cell and cx < FIG[2] + Ent.CLEAR + cell and cy > FIG[1] - Ent.CLEAR - cell and cy < FIG[3] + Ent.CLEAR + cell
        var near_rack: bool = cx > RACK[0] - Ent.CLEAR - cell and cx < RACK[2] + Ent.CLEAR + cell and cy > RACK[1] - Ent.CLEAR - cell and cy < RACK[3] + Ent.CLEAR + cell
        if not near_fig and not near_rack:
            near_only = false
            far_cells.append(Vector2(cx, cy))
    var lb := Rect2()
    for v in lost:
        lb = Rect2(Vector2(v.x * cell, v.y * cell), Vector2(cell, cell)) if lb.size == Vector2.ZERO else lb.merge(Rect2(Vector2(v.x * cell, v.y * cell), Vector2(cell, cell)))
    print("    多挡 %d 格（每格 %d 像素），范围 %s；多出来能走的 %d 格；离两块占地 12+1 格以外的 %d 格 %s" % [lost.size(), cell, str(lb), gained.size(), far_cells.size(), str(far_cells.slice(0, 6))])
    check("多挡的格子都在两块占地四周（没有顺带把远处的格子圈掉）", near_only and gained.is_empty())

    # 5 孤岛
    print("5 休息间里能走的格子都连着 lounge 点")
    var cols_n: int = b.cols
    var rows_n: int = b.rows
    var seen := {}
    var st: Array = []
    var start: Vector2i = b._cell_of(b.points["lounge"]["pos"])
    if b.walk[start.y * cols_n + start.x] != 1:
        start = b._nearest_free(start)
    st.append(start)
    seen[start] = true
    while not st.is_empty():
        var cc: Vector2i = st.pop_back()
        for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
            var nn: Vector2i = cc + d
            if nn.x < 0 or nn.y < 0 or nn.x >= cols_n or nn.y >= rows_n or seen.has(nn):
                continue
            if b.walk[nn.y * cols_n + nn.x] == 1:
                seen[nn] = true
                st.append(nn)
    var islands := 0
    var total_lounge := 0
    for j in rows_n:
        for i in cols_n:
            var cp := Vector2((i + 0.5) * cell, (j + 0.5) * cell)
            if LOUNGE.has_point(cp) and b.walk[j * cols_n + i] == 1:
                total_lounge += 1
                if not seen.has(Vector2i(i, j)):
                    islands += 1
    print("    休息间能走的格子 %d 个，连不上 lounge 点的 %d 个" % [total_lounge, islands])
    check("休息间没有孤岛", islands == 0)

    # 3 贴着占地推摇杆
    print("3 贴着新占地推摇杆")
    var stuck_in := 0
    var cant_leave := 0
    var tried := 0
    for ob in [FIG, RACK]:
        var c0 := Vector2((ob[0] + ob[2]) * 0.5, (ob[1] + ob[3]) * 0.5)
        for k in 12:
            var ang := TAU * k / 12.0
            var dir := Vector2(cos(ang), sin(ang))
            for dist in [4.0, 8.0, 14.0, 24.0, 40.0]:
                var p0: Vector2 = c0 + dir * (dist + 6.0)
                if not b._free(p0):
                    continue
                tried += 1
                reenter()
                b.reset_to(p0)
                b.path.clear()
                b.stick = -dir
                for f in 120:
                    b._process(DT)
                if not b._free(b.pos):
                    stuck_in += 1
                    print("    被带进了占地：从 ", p0, " 朝 ", -dir, " → ", b.pos)
                b.stick = dir
                var before: Vector2 = b.pos
                for f in 60:
                    b._process(DT)
                b.stick = Vector2.ZERO
                if b.pos.distance_to(c0) < before.distance_to(c0) + 5.0 and not (b.pos - before).length() > 10.0:
                    cant_leave += 1
                    print("    朝外走不开：从 ", before, " 朝 ", dir, " → ", b.pos)
    print("    试了 %d 个站位" % tried)
    check("没有被带进占地、朝外都走得开（%d 个站位）" % tried, stuck_in == 0 and cant_leave == 0 and tried >= 8)

    # 4 唱片机前
    print("4 唱片机前 (424,320)")
    var spot := Vector2(424, 320)
    check("站得进去（格子能走）", b._free(spot))
    var ccount := 0
    var w := 0
    var best_sq := 0
    for j in rows_n:
        for i in cols_n:
            var cp := Vector2((i + 0.5) * cell, (j + 0.5) * cell)
            if Rect2(396, 290, 56, 60).has_point(cp) and b.walk[j * cols_n + i] == 1:
                ccount += 1
    # 最大空地：以 spot 为中心找能站的最大方块（格数）
    for half in range(1, 9):
        var all_ok := true
        for dy in range(-half, half):
            for dx in range(-half, half):
                var p := spot + Vector2(dx * cell + cell * 0.5, dy * cell + cell * 0.5)
                if not b._free(p):
                    all_ok = false
        if all_ok:
            best_sq = half * 2
    print("    旁边 56×60 里能站 %d 格（共 %d 格）；以 (424,320) 为中心最大的全能站方块 %d×%d 格 = %d 像素见方" % [ccount, int(56 / cell + 1) * int(60 / cell + 1), best_sq, best_sq, best_sq * cell])
    check("唱片机前能站进人（≥ 3×3 格 = 36 像素见方的空地）", best_sq >= 3)
    print("  共 %.1f 秒" % ((Time.get_ticks_msec() - t_start) / 1000.0))
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
