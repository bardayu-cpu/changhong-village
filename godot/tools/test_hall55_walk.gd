extends SceneTree
## 窄缝走路测试（01 E 10/2 派，03 写）：55 桌厅排法 C 第 1 档有十几处两张桌挨得近（占地之间 < 43，人宽）。
## 「格子连通」不等于人真走得过去：这里照玩家推摇杆那样一步步走（layered_hall._stick_move，每帧 1/60 秒，朝寻路给的下一个拐点推满摇杆，
## 挡住了就按游戏自己的规矩贴着桌边滑），卡住超过 2 秒不往前算失败。不改游戏代码。
##   1 从大门口（进场点）走到每一张桌的每把椅子旁边最近能站的格子（站那儿离椅子 ≤ NEAR_R 78 就出「坐这儿」），550 把，重点看窄缝那几处
##   2 窄缝：每一对占地之间 < 43 的桌，在最窄处垂直穿过去走一趟（通的走得过吗？不通的记一笔，人本来就绕）
##   3 从主桌走到最远的一张（路最长的），再走回来
## 用法：Godot --headless --path . --script res://tools/test_hall55_walk.gd
## 最后一行 RESULT PASS 才算过；卡住的写在「卡住」那几行里（哪张桌几号椅、卡在哪、离哪个拐点多远）

const Main = preload("res://scripts/main.gd")
const LayeredHall = preload("res://scripts/layered_hall.gd")
const DT := 1.0 / 60.0
const STUCK_SECS := 2.0     # 往目标的距离超过这么久没缩小就算卡住
const NARROW := 43.0        # 人宽：两张桌占地之间比这窄的算窄缝
const MAX_LEG := 180.0      # 一段路最多走这么久（秒），防死循环

var m
var started := false
var ok := true

func _initialize() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
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

## 椭圆占地之间最近多远（两个同样大小的椭圆，圈心差 d，边到边），数值算，返回 [距离, 点 1, 点 2]
func ellipse_gap(c1: Vector2, c2: Vector2, a: float, b: float) -> Array:
    var best := 1.0e9
    var p1 := Vector2.ZERO
    var p2 := Vector2.ZERO
    var n := 120
    for i in n:
        var u := Vector2(cos(TAU * i / n) * a, sin(TAU * i / n) * b) + c1
        for j in n:
            var v := Vector2(cos(TAU * j / n) * a, sin(TAU * j / n) * b) + c2
            var d := u.distance_to(v)
            if d < best:
                best = d
                p1 = u
                p2 = v
    return [best, p1, p2]

## 从 h.pos 沿寻路的拐点用摇杆走到 target。回 {ok, secs, stuck_at, wp, wp_i, n_wp, err}
func stick_walk(h, target: Vector2) -> Dictionary:
    var res := {"ok": false, "secs": 0.0}
    var path: Array = h.find_path(h.pos, target)
    if path.is_empty():
        res["err"] = "寻路没路"
        return res
    res["n_wp"] = path.size()
    h.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - h.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        h.stick = d.normalized()
        h._process(DT)
        total += DT
        var nd: float = (wp - h.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= STUCK_SECS:
            res["stuck_at"] = h.pos
            res["wp"] = wp
            res["wp_i"] = wi
            res["secs"] = total
            h.stick = Vector2.ZERO
            return res
        if total > MAX_LEG:
            res["err"] = "超时 %.0f 秒" % MAX_LEG
            res["stuck_at"] = h.pos
            res["secs"] = total
            h.stick = Vector2.ZERO
            return res
    h.stick = Vector2.ZERO
    res["secs"] = total
    res["ok"] = true
    return res

## 直着走一趟（不寻路）：从 a 推摇杆到 b，卡住 2 秒算失败。回 {ok, secs, stuck_at}
func straight_walk(h, a: Vector2, b: Vector2) -> Dictionary:
    h.reset_to(a)
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while (b - h.pos).length() > 3.0:
        h.stick = (b - h.pos).normalized()
        h._process(DT)
        total += DT
        var nd: float = (b - h.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= STUCK_SECS or total > 60.0:
            h.stick = Vector2.ZERO
            return {"ok": false, "secs": total, "stuck_at": h.pos}
    h.stick = Vector2.ZERO
    return {"ok": true, "secs": total}

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    await m._enter_banquet()
    await create_timer(0.5).timeout
    var h = m.hall
    var tabs: Array = h.cfg["tables"]
    check("默认是 55 桌厅：%d 张桌，画布 %s" % [tabs.size(), h.cfg["size"]], h.big and tabs.size() == 55)
    m.dialog.visible = false
    h.walking_enabled = true
    h.couple_armed = false
    var spawn: Vector2 = h.SPAWN
    var t_start := Time.get_ticks_msec()

    # ---- 自检：这个测试抓得到卡住吗？直着往一张桌子里推，必须被挡住、判卡住 ----
    var t1: Dictionary = h._table_cfg("T1")
    var wall := straight_walk(h, Vector2(float(t1["x"]) - 130.0, float(t1["y"])), Vector2(float(t1["x"]) + 130.0, float(t1["y"])))
    check("自检：直着往 T1 桌子里推被挡住、判卡住（%s）" % [wall], not wall["ok"] and wall.has("stuck_at"))

    # ---- 窄缝是哪几对 ----
    print("== 窄缝（桌占地之间 < %.0f）" % NARROW)
    var narrow: Array = []
    for i in tabs.size():
        for j in range(i + 1, tabs.size()):
            var ti: Dictionary = tabs[i]
            var tj: Dictionary = tabs[j]
            var c1 := Vector2(float(ti["x"]), float(ti["y"]))
            var c2 := Vector2(float(tj["x"]), float(tj["y"]))
            if c1.distance_to(c2) > 2.0 * 73.0 + NARROW + 40.0 + 40.0:
                continue
            var g: Array = ellipse_gap(c1, c2, float(ti["rx"]), float(ti["ry"]))
            if float(g[0]) < NARROW:
                narrow.append({"a": str(ti["id"]), "b": str(tj["id"]), "gap": float(g[0]), "p1": g[1], "p2": g[2]})
    narrow.sort_custom(func(x, y): return float(x["gap"]) < float(y["gap"]))
    var in_narrow := {}
    for n in narrow:
        in_narrow[n["a"]] = true
        in_narrow[n["b"]] = true
        print("  %s — %s：占地之间 %.1f" % [n["a"], n["b"], n["gap"]])
    print("  共 %d 处，涉及 %d 张桌" % [narrow.size(), in_narrow.size()])

    # ---- 1 从大门走到每把椅子 ----
    print("== 1 从大门口一步步走到每把椅子的站位")
    var stuck: Array = []
    var no_path: Array = []
    var far_stand: Array = []
    var n_chairs := 0
    var n_ok := 0
    var longest := 0.0
    var longest_who := ""
    var narrow_chairs := 0
    var narrow_ok := 0
    for t in tabs:
        var tid: String = str(t["id"])
        for no in range(1, LayeredHall.seats_of(t) + 1):
            n_chairs += 1
            var chair: Vector2 = h.chair_world(t, no)
            var stand: Vector2 = h._cell_pos(h._nearest_free(h._cell_of(chair)))   # 椅子旁边最近能站的格子（站那儿离椅子 ≤ NEAR_R 就出「坐这儿」）
            if stand.distance_to(chair) > LayeredHall.NEAR_R:
                far_stand.append("%s:%d(%.0f)" % [tid, no, stand.distance_to(chair)])
            h.reset_to(spawn)
            var r := stick_walk(h, stand)
            var is_n: bool = in_narrow.has(tid)
            if is_n:
                narrow_chairs += 1
            if r["ok"] and h.pos.distance_to(stand) < 8.0:
                n_ok += 1
                if is_n:
                    narrow_ok += 1
                if float(r["secs"]) > longest:
                    longest = float(r["secs"])
                    longest_who = "%s:%d" % [tid, no]
            elif r.has("err") and str(r["err"]) == "寻路没路":
                no_path.append("%s:%d" % [tid, no])
            else:
                stuck.append({"who": "%s:%d" % [tid, no], "narrow": is_n, "stand": stand, "r": r})
    print("  椅子 %d 把，走到了 %d 把；窄缝那几张桌的椅子 %d 把，走到 %d 把；最远一趟 %.1f 秒（%s）" % [n_chairs, n_ok, narrow_chairs, narrow_ok, longest, longest_who])
    check("550 把椅子都有寻路（没路 %s）" % [no_path], no_path.is_empty())
    check("最近能站的格子离椅子都在「坐这儿」的范围 %.0f 以内（超出 %s）" % [LayeredHall.NEAR_R, far_stand], far_stand.is_empty())
    for s in stuck:
        var rr: Dictionary = s["r"]
        print("  卡住 %s%s：目标 (%.0f, %.0f)，卡在 (%.0f, %.0f)，正走向拐点 %s（第 %s/%s 个），%s，走了 %.1f 秒" % [s["who"], "（窄缝桌）" if s["narrow"] else "", s["stand"].x, s["stand"].y,
            rr["stuck_at"].x if rr.has("stuck_at") else -1.0, rr["stuck_at"].y if rr.has("stuck_at") else -1.0, str(rr.get("wp", "?")), str(rr.get("wp_i", "?")), str(rr.get("n_wp", "?")), str(rr.get("err", "卡住超过 2 秒")), float(rr.get("secs", 0.0))])
    check("每把椅子都能一步步走到（卡住 %d 把）" % stuck.size(), stuck.is_empty())

    # ---- 2 窄缝：垂直穿过去 ----
    print("== 2 窄缝垂直穿过去")
    var passable := 0
    var blocked := 0
    var stuck_gap: Array = []
    for n in narrow:
        var p1: Vector2 = n["p1"]
        var p2: Vector2 = n["p2"]
        var mid: Vector2 = (p1 + p2) * 0.5
        var gdir: Vector2 = (p2 - p1)
        gdir = gdir.normalized() if gdir.length() > 0.01 else Vector2.RIGHT
        var tdir := Vector2(-gdir.y, gdir.x)   # 缝走向（垂直于两点连线）
        var a: Vector2 = mid - tdir * 70.0
        var b: Vector2 = mid + tdir * 70.0
        var cell_free: bool = h._free(mid)
        if not cell_free or not h._free(a) or not h._free(b):
            blocked += 1
            print("  %s — %s（缝 %.1f）：最窄处 (%.0f, %.0f) 不能站/两头不能站，人走不进去（绕）" % [n["a"], n["b"], n["gap"], mid.x, mid.y])
            continue
        var r1 := straight_walk(h, a, b)
        var r2 := straight_walk(h, b, a)
        if r1["ok"] and r2["ok"]:
            passable += 1
            print("  %s — %s（缝 %.1f）：通，来回都走过去了（%.1f、%.1f 秒）" % [n["a"], n["b"], n["gap"], r1["secs"], r2["secs"]])
        else:
            stuck_gap.append("%s—%s" % [n["a"], n["b"]])
            print("  %s — %s（缝 %.1f）：能站但走不过去：正向 %s、反向 %s，卡在 %s" % [n["a"], n["b"], n["gap"], r1["ok"], r2["ok"], str(r1.get("stuck_at", r2.get("stuck_at", "?")))])
    print("  窄缝 %d 处：走得过去 %d、本来就不通（人绕）%d、能站却走不过去 %d" % [narrow.size(), passable, blocked, stuck_gap.size()])
    check("窄缝里没有「能站却卡住」的（%s）" % [stuck_gap], stuck_gap.is_empty())

    # ---- 3 主桌到最远一张 ----
    print("== 3 从主桌走到最远的一张，再走回来")
    var main_t: Dictionary = h._table_cfg("MAIN")
    var main_stand: Vector2 = h._cell_pos(h._nearest_free(h._cell_of(h.chair_world(main_t, 1))))
    var far_id := ""
    var far_len := 0.0
    var far_stand_pt := Vector2.ZERO
    for t in tabs:
        if str(t["id"]) == "MAIN":
            continue
        var st: Vector2 = h._cell_pos(h._nearest_free(h._cell_of(h.chair_world(t, 1))))
        var pp: Array = h.find_path(main_stand, st)
        var len_ := 0.0
        var cur: Vector2 = main_stand
        for w in pp:
            len_ += cur.distance_to(w)
            cur = w
        if len_ > far_len:
            far_len = len_
            far_id = str(t["id"])
            far_stand_pt = st
    h.reset_to(main_stand)
    var go := stick_walk(h, far_stand_pt)
    var back := stick_walk(h, main_stand)
    print("  最远一张 %s，路程约 %.0f 像素；去 %s %.1f 秒，回 %s %.1f 秒" % [far_id, far_len, go["ok"], go["secs"], back["ok"], back["secs"]])
    check("主桌 → %s 走得到" % far_id, go["ok"] and h.pos.distance_to(main_stand) < 8.0 or go["ok"])
    check("%s → 主桌 走得回来" % far_id, back["ok"] and h.pos.distance_to(main_stand) < 8.0)

    print("（全程用了 %.0f 秒）" % ((Time.get_ticks_msec() - t_start) / 1000.0))
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
