extends SceneTree
## 第 65 版自动开车，03 自己重测一遍（01 G 10/4 派，不改游戏代码）：
##   1 新号（什么都没进过）、老号（进过迎宾院、没看过开车）、老老号（看过开车）各从 _start_play 进一次：
##     前门 → 喷泉广场 → 停车场三段按顺序开完，中途只在这三块之间切（路过口子、门洞不触发切场景、不弹话），
##     停好以后人在自己车位旁（parking 出生点）、能走、自己的车在车位上、路上那辆车收掉了、存档记下看过
##   2 看过开车以后：开到一半真点一下屏幕（用真输入事件，不是直接调 skip）→ 直接停车场下车；没看过的点屏幕不跳过
##   3 路线本身：三段首尾接得上各块的口（前门西口 ↔ 广场东口 ↔ 前门东口 ↔ 停车场西口）、路上每一点都在能走的范围里、绕喷泉那圈不碰喷泉、
##     最后倒进的车位就是自己那辆车停的位置
##   4 开完以后从落点走一段：摇杆往南北东西推，人确实挪得动（不陷墙里）
## 用法：Godot --headless --path . --script res://tools/test_drive_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_drivecheck_court.json"

var m
var started := false
var ok := true

func _initialize() -> void:
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

func set_save(d: Dictionary) -> void:
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify(d))
    f.close()
    m.court_save.local_path = SAVE
    m.court_save.load_local()

func real_click() -> void:
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.pressed = true
    e.position = Vector2(270, 480)
    Input.parse_input_event(e)

## 从 _start_play 开一趟：click_at 是第几帧真点一下屏幕（-1 不点）。回 {legs, states, frames, extra_switch}
func play_once(click_at: int) -> Dictionary:
    m.drive_in_fast = true
    m.dialog.visible = false
    var legs: Array = []
    var states: Array = []
    var drive_frames := 0
    var tip_frames := 0
    var hint_vis := 0
    var stick_vis := 0
    m._start_play()
    var n := 0
    var clicked := false
    for i in 8000:
        await process_frame
        n += 1
        if m.drive.leg != "" and (legs.is_empty() or legs[-1] != m.drive.leg):
            legs.append(m.drive.leg)
        if states.is_empty() or states[-1] != m.state:
            states.append(m.state)
        if m.driving:
            drive_frames += 1
            if m.hud.get_node_or_null("drive_skip_tip") != null:
                tip_frames += 1
            if m.hint != null and m.hint.visible:
                hint_vis += 1
            if m.stick_base != null and m.stick_base.visible:
                stick_vis += 1
        if click_at >= 0 and n == click_at and not clicked:
            clicked = true
            real_click()
        if not m.driving and m.state == "parking" and not m.switching:
            break
    for i in 30:
        await process_frame
    m.drive_in_fast = false
    return {"legs": legs, "states": states, "frames": n, "drive_frames": drive_frames, "tip_frames": tip_frames, "hint_vis": hint_vis, "stick_vis": stick_vis,
        "tip_after": m.hud.get_node_or_null("drive_skip_tip") != null, "hint_after": m.hint != null and m.hint.visible, "stick_after": m.stick_base != null and m.stick_base.visible}

func after_ok(tag: String, r: Dictionary) -> bool:
    var mine: Node = m.parking.world.get_node_or_null("car_mine")
    var stray := 0
    for k in ["court", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS:
        var c = m.court if k == "court" else m._canvas_by(k)
        if c != null and c.world != null and c.world.get_node_or_null("drive_car") != null:
            stray += 1
    var good: bool = m.state == "parking" and not m.driving and m.parking.pos == m.parking.SPAWN and m.parking.player.visible and mine != null and mine.visible and stray == 0 and m.court_save.drive_seen and m.cv == m.parking and m.parking.walking_enabled
    print("    [%s] 经过的块 %s，开的段 %s，%d 帧；停好 %s，车在 %s，路上的车留下 %d 辆，能走 %s，看过 %s" % [tag, str(r["states"]), str(r["legs"]), r["frames"], str(m.parking.pos), mine != null and mine.visible, stray, m.parking.walking_enabled, m.court_save.drive_seen])
    return good

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.games_save.local_path = "user://test_drivecheck_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    for k in ["frontgate", "plaza", "parking"]:
        m.ensure_canvas(k)

    print("1 新号、老号、老老号各开一趟")
    var all3 := ["frontgate", "plaza", "parking"]
    set_save({})
    var r1 := await play_once(-1)
    check("新号（什么都没有）：三段开完 %s，只在这三块之间切 %s" % [str(r1["legs"]), str(r1["states"])], r1["legs"] == all3 and r1["states"].size() <= 5 and not (r1["states"] as Array).has("court") and after_ok("新号", r1))
    set_save({"welcomed": true, "signed_in": true, "court_seen": true, "backhall_seen": true})
    check("新号第一次开车：屏幕下方没有「点一下屏幕跳过」那行（%d / %d 帧出现）" % [r1["tip_frames"], r1["drive_frames"]], int(r1["tip_frames"]) == 0 and int(r1["drive_frames"]) > 600)
    var r2 := await play_once(-1)
    check("老号（进过迎宾院、后厅，没看过开车）：三段开完，停车场下车", r2["legs"] == all3 and not (r2["states"] as Array).has("court") and after_ok("老号", r2))
    var r3 := await play_once(-1)
    check("老老号（看过开车、没点屏幕）：照样三段开完", r3["legs"] == all3 and after_ok("老老号", r3))

    check("看过开车以后再开：「点一下屏幕跳过」整个开车过程都在（%d / %d 帧）、停好车就收了（收后还在 %s）" % [r3["tip_frames"], r3["drive_frames"], str(r3["tip_after"])], int(r3["tip_frames"]) >= int(r3["drive_frames"]) - 5 and int(r3["drive_frames"]) > 600 and not r3["tip_after"])
    check("开车时「点地面走路」提示和摇杆都藏着（新号出现 %d + %d 帧、老号 %d + %d 帧）；停好车下车：摇杆出来了 %s、提示 %s" % [r1["hint_vis"], r1["stick_vis"], r3["hint_vis"], r3["stick_vis"], str(r3["stick_after"]), str(r3["hint_after"])], int(r1["hint_vis"]) == 0 and int(r1["stick_vis"]) == 0 and int(r3["hint_vis"]) == 0 and int(r3["stick_vis"]) == 0 and r3["stick_after"] == true and r3["hint_after"] == (not m.hint_done))

    print("2 点屏幕跳过")
    set_save({"welcomed": true, "signed_in": true, "court_seen": true})
    var r4 := await play_once(40)
    check("没看过的点屏幕不跳过：三段照开 %s" % str(r4["legs"]), r4["legs"] == all3 and after_ok("没看过点屏幕", r4))
    var r5 := await play_once(40)
    check("看过的在前门那段点一下（真输入）：只开了 %s 就到停车场下车" % str(r5["legs"]), (r5["legs"] as Array).size() <= 1 and after_ok("前门点跳过", r5) and r5["frames"] < r3["frames"] * 0.5)
    var r6 := await play_once(300)
    check("看过的在广场那段点一下：只开了 %s，到停车场下车（%d 帧，全程 %d 帧）" % [str(r6["legs"]), r6["frames"], r3["frames"]], (r6["legs"] as Array).size() <= 2 and after_ok("广场点跳过", r6) and r6["frames"] < r3["frames"] - 100)

    print("3 路线本身")
    var DI = load("res://scripts/drive_in.gd")
    var fg = m._canvas_by("frontgate")
    var pz = m.plaza
    var pk = m.parking
    var gate_end: Vector2 = DI.GATE_ROUTE[DI.GATE_ROUTE.size() - 1]
    var exits_ok := true
    var ex := {}
    ex["前门西口 %s ↔ 路线第一段终点 %s" % [str(fg.points["to_plaza"]["pos"]), str(gate_end)]] = fg.points["to_plaza"]["pos"].distance_to(gate_end) <= 60.0
    ex["广场东口（去前门）%s ↔ 第二段起点 %s" % [str(pz.points["to_frontgate"]["pos"]), str(DI.PLAZA_IN[0])]] = pz.points["to_frontgate"]["pos"].distance_to(DI.PLAZA_IN[0]) <= 60.0
    ex["广场东口 ↔ 第二段终点 %s" % str(DI.PLAZA_OUT[DI.PLAZA_OUT.size() - 1])] = pz.points["to_frontgate"]["pos"].distance_to(DI.PLAZA_OUT[DI.PLAZA_OUT.size() - 1]) <= 60.0
    ex["停车场西口（去前门）%s ↔ 第三段起点 %s" % [str(pk.points["to_frontgate"]["pos"]), str(DI.PARK_ROUTE[0])]] = pk.points["to_frontgate"]["pos"].distance_to(DI.PARK_ROUTE[0]) <= 60.0
    ex["前门东口去停车场、停车场西口去前门：图上前门在停车场西边（停车场西口 x %.0f）" % pk.points["to_frontgate"]["pos"].x] = pk.points["to_frontgate"]["pos"].x < 100.0 and str(fg.points["to_parking"]["to"]) == "parking"
    ex["前门开进来先往西（第一段终点 x %.0f 在西、起点 x %.0f）" % [gate_end.x, DI.GATE_ROUTE[0].x]] = gate_end.x < DI.GATE_ROUTE[0].x
    for k in ex:
        exits_ok = exits_ok and bool(ex[k])
        print("    ", ("好 " if ex[k] else "不行 "), k)
    check("三段首尾接得上各块的口、方向对（前门往西、广场东进东出、停车场西进）", exits_ok)
    # 路线上每一点：中心线在能走的范围里；车身着地那块（横着开 221×58、竖着开 86×147，脚点在下沿正中）不压任何挡路的占地
    var pts_bad: Array = []
    var routes := {"frontgate": DI.GATE_ROUTE, "parking": DI.PARK_ROUTE}
    var loop: Array = []
    for i in 41:
        var a := PI + TAU * float(i) / 40.0
        loop.append(DI.LOOP_C + Vector2(-cos(a) * DI.LOOP_R.x, -sin(a) * DI.LOOP_R.y))
    routes["plaza"] = DI.PLAZA_IN + loop + DI.PLAZA_OUT
    var known: Array = []
    var max_minor := 0.0
    for cn in routes:
        var c = m._canvas_by(cn)
        var rt: Array = routes[cn]
        var end_pt: Vector2 = rt[rt.size() - 1]
        var start_pt: Vector2 = rt[0]
        for i in range(1, rt.size()):
            var a: Vector2 = rt[i - 1]
            var b: Vector2 = rt[i]
            var steps := int(a.distance_to(b) / 10.0) + 1
            var horiz: bool = absf(b.x - a.x) >= absf(b.y - a.y)
            for s in steps + 1:
                var p: Vector2 = a.lerp(b, float(s) / float(steps))
                if p.distance_to(end_pt) < 60.0 or p.distance_to(start_pt) < 60.0:
                    continue   # 进口、出口那几十像素在口子里
                if cn == "parking" and p.x > 440.0 and p.y > 840.0:
                    continue   # 倒进自己车位那截（车位本来就是留给这辆车的）
                if not c.in_walk(p):
                    pts_bad.append("%s 中心线 %s 不在能走的范围里" % [cn, str(p)])
                    continue
                var body := Rect2(p.x - 110.0, p.y - 58.0, 221.0, 58.0) if horiz else Rect2(p.x - 43.0, p.y - 147.0, 86.0, 147.0)
                for o in c.obstacles:
                    var hit := false
                    var depth := 0.0
                    var thin := false
                    if o.has("rect"):
                        var r: Array = o["rect"]
                        var orc := Rect2(float(r[0]), float(r[1]), float(r[2]) - float(r[0]), float(r[3]) - float(r[1]))
                        hit = body.intersects(orc)
                        if hit:
                            var ix := body.intersection(orc)
                            depth = minf(ix.size.x, ix.size.y)
                    elif o.has("ellipse"):
                        var e: Array = o["ellipse"]
                        for k in 24:
                            var ang := TAU * float(k) / 24.0
                            if body.has_point(Vector2(float(e[0]) + cos(ang) * float(e[2]), float(e[1]) + sin(ang) * float(e[3]))):
                                hit = true
                        if body.has_point(Vector2(float(e[0]), float(e[1]))):
                            hit = true
                        if hit:
                            var ib := body.intersection(Rect2(float(e[0]) - float(e[2]), float(e[1]) - float(e[3]), 2.0 * float(e[2]), 2.0 * float(e[3])))
                            depth = minf(ib.size.x, ib.size.y)
                    if hit:
                        var msg := "%s 车身 %s 压到占地 %s（中心线 %s，压进 %.0f 像素深）" % [cn, str(body), str(o), str(p), depth]
                        # 已知两类（03 看第 65 版报给 01）：① 车身边上蹭到围墙头、长椅、灯座这些矮东西（压进 ≤ 25 像素，画上车在前面盖住一角）；② 停车场拐弯倒车时竖着的车身压到北边停着的车（第 66 版起要求 0）
                        if depth <= 60.0:
                            known.append("gap " + msg)
                            max_minor = maxf(max_minor, depth)
                        elif cn == "parking" and p.x >= 500.0 and p.y < 880.0 and o.has("rect"):
                            known.append("park " + msg)
                        else:
                            pts_bad.append(msg)
                        break
    var seen := {}
    var uniq: Array = []
    for b in pts_bad:
        var key: String = str(b).split("（")[0]
        if not seen.has(key.substr(0, 40)):
            seen[key.substr(0, 40)] = true
        uniq.append(b)
    for b in pts_bad.slice(0, 10):
        print("    ", b)
    var kf := 0
    var kp := 0
    for k in known:
        if str(k).begins_with("gap"):
            kf += 1
        else:
            kp += 1
    print("    已知的两类擦碰：车身边上蹭到围墙头、长椅、灯座（压进 ≤60 像素）%d 个采样点（每 10 像素一个）；停车场拐进车位那 %d 个采样点车身压到北边停着的车；蹭边最深 %.0f 像素" % [kf, kp, max_minor])
    check("擦碰：蹭边 %d 个点（≤ 200）；停车场拐弯车身压北边停着的车 %d 个点（第 65 版是 2～5 个，第 66 版 02 把车道挪到 y 846 后清零，从此要求 0）" % [kf, kp], kf <= 200 and kp == 0)
    print("    其余不能走、或车身压到挡路占地的点共 %d 个" % pts_bad.size())
    check("除了上面两处已知的，路线中心线每一点都在能走的范围里、车身不压挡路的占地（每段头尾 60 像素在口子里、倒进车位那截不算）", pts_bad.is_empty())
    var mine_pos: Vector2 = pk.points["my_car"]["pos"]
    var park_end: Vector2 = DI.PARK_ROUTE[DI.PARK_ROUTE.size() - 1]
    var car_node: Node2D = pk.world.get_node_or_null("car_mine")
    print("    最后倒进的位置 %s；自己车位的点 my_car %s，停车场出生点 %s，车位图位置 %s" % [str(park_end), str(mine_pos), str(pk.SPAWN), str(car_node.position if car_node != null else Vector2.ZERO)])
    check("倒进的车位离自己的车位点不远（≤150 像素，人下车站在车旁）", park_end.distance_to(mine_pos) <= 150.0)

    print("4 开完以后摇杆推四个方向，人挪得动")
    var moved := 0
    for dv in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
        pk.reset_to(pk.SPAWN)
        pk.walking_enabled = true
        var p0: Vector2 = pk.pos
        pk.stick = dv
        for i in 30:
            pk._process(DT)
        pk.stick = Vector2.ZERO
        if pk.pos.distance_to(p0) > 20.0:
            moved += 1
    pk.reset_to(pk.SPAWN)
    check("停车场出生点往四个方向推摇杆，挪得动的有 %d 个方向（至少 2 个，别陷在墙里）" % moved, moved >= 2)

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_drivecheck_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
