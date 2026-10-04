extends SceneTree
## 第 67 版湖边动效（05 做：湖面波光 + 小船起伏），03 自己重测（01 H 10/4 派，不改游戏代码；不看 05 的 test_ambient_lake，另起量法）。
## 画出来的像素、每帧画几次要开窗口量，见 check_lake_glint.gd；这里是无界面能量的：
##   1 湖边挂了动效：两块波光（东、西）+ 一组小船（5 条），波光紧贴在各自背景图后面一个、同一层（背景上面、人和零件下面）；迎宾院、草坪、果园这些没写配置的块不挂
##   2 小船：5 条都找到（名字对）；各自 20 秒里往上提的只会是 0 或 1 像素、着地线（position.y）一直没动、只动图（offset）；
##     一圈 1.6～2.4 秒（从换档间隔反推）；5 条不同步；全关档（0）回原位
##   3 降级：2 档波光亮的机会 = 配置值（0.05）；1 档减半（0.025）；0 档整个藏掉；船在 1 档照常、0 档回原位；切走（去迎宾院）动效节点停
##   4 第一次走路的提示框（右下「点地面走路」）跟湖边两道月亮门的「去…」牌：手机 540×960 和长屏 585×1266，人站在门里边和门口，提示框开着，
##     牌子（换成屏幕坐标）跟提示框不叠
## 用法：Godot --headless --path . --script res://tools/test_ambient_lake_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ambient = preload("res://scripts/ambient/ambient.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(120.0).timeout.connect(func():
        print("RESULT FAIL 120 秒没跑完")
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

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_alcheck_court.json"
    m.games_save.local_path = "user://test_alcheck_games.json"
    for k in ["lake", "lawn", "orchard", "plaza", "parking", "backhall"]:
        m.ensure_canvas(k)
    await m._enter_court()
    m.dialog.visible = false
    var lk = m.lake
    m._show_canvas("lake")
    m._goto("lake")
    await frames(2)
    Ambient.set_forced(-1)

    print("1 挂了什么")
    var amb = lk.get_node_or_null("ambient")
    check("湖边挂了动效总节点", amb != null)
    var glints: Array = amb.effects.filter(func(e): return e is Sprite2D)
    var bobs: Array = amb.effects.filter(func(e): return e is Node and not (e is Sprite2D) and e.get("boats") != null)
    check("两块波光、一组小船（共 %d 样：波光 %d、船组 %d）" % [amb.effects.size(), glints.size(), bobs.size()], glints.size() == 2 and bobs.size() == 1)
    var place_bad: Array = []
    for g in glints:
        var par: Node = g.get_parent()
        var bg_name := "px_background_lake_" + ("west" if str(g.name).ends_with("west") else "east")
        var bg: Node = par.get_node_or_null(bg_name)
        if bg == null:
            place_bad.append("%s 找不到 %s" % [g.name, bg_name])
            continue
        if g.get_index() != bg.get_index() + 1:
            place_bad.append("%s 不在背景后一个（%d vs %d）" % [g.name, g.get_index(), bg.get_index()])
        if g.z_index != bg.z_index:
            place_bad.append("%s 层 %d ≠ 背景 %d" % [g.name, g.z_index, bg.z_index])
        if (g.position - (bg as Sprite2D).position - Vector2(g.region_rect.position)).length() > 0.01:
            place_bad.append("%s 位置 %s 对不上背景 %s + 水面起点 %s" % [g.name, str(g.position), str((bg as Sprite2D).position), str(g.region_rect.position)])
        # 在人和零件下面：世界节点（world）在 flat 上面
        if par == lk.world:
            place_bad.append("%s 挂在 world 里了（会跟人排前后）" % g.name)
    for x in place_bad:
        print("    ", x)
    check("两块波光位置、层次对（%d 处不对）" % place_bad.size(), place_bad.is_empty())
    var other_has := false
    for k in ["lawn", "orchard", "plaza", "parking", "backhall"]:
        if m._canvas_by(k).get_node_or_null("ambient") != null:
            other_has = true
    check("草坪、果园、广场、停车场、后厅没挂动效（配置里没写）", not other_has)

    print("2 小船")
    var bb = bobs[0]
    var want_ids := ["px_w_rowboat_1", "px_w_rowboat_2", "px_w_swanboat_1", "px_w_swanboat_2", "px_boat"]
    var got_ids: Array = bb.boats.map(func(x): return str((x["s"] as Sprite2D).name))
    check("5 条船都找到、名字对 %s" % str(got_ids), got_ids == want_ids)
    var y0: Array = bb.boats.map(func(x): return float((x["s"] as Sprite2D).position.y))
    var o0: Array = bb.boats.map(func(x): return float(x["y"]))
    var dt := 1.0 / 30.0
    var changes: Array = []
    var last_lift: Array = []
    var lifts_seen: Array = []
    var foot_moved := false
    var off_bad := false
    var switch_t: Array = []
    for i in bb.boats.size():
        changes.append(0)
        last_lift.append(-1)
        lifts_seen.append({})
        switch_t.append([])
    var t := 0.0
    for step in int(24.0 / dt):
        t += dt
        bb._process(dt)
        for i in bb.boats.size():
            var s: Sprite2D = bb.boats[i]["s"]
            var lift: float = o0[i] - s.offset.y
            if lift != 0.0 and lift != 1.0:
                off_bad = true
            if absf(s.position.y - y0[i]) > 0.001:
                foot_moved = true
            if int(lift) != int(last_lift[i]):
                if int(last_lift[i]) >= 0:
                    (switch_t[i] as Array).append(t)
                last_lift[i] = lift
            (lifts_seen[i] as Dictionary)[int(lift)] = true
    check("船只往上提 0 或 1 像素（%s）、着地线 position.y 一直没动（%s）" % [str(not off_bad), str(not foot_moved)], not off_bad and not foot_moved)
    var per_ok := true
    var per_txt: Array = []
    var phases := {}
    for i in bb.boats.size():
        var sw: Array = switch_t[i]
        if sw.size() < 6 or (lifts_seen[i] as Dictionary).size() != 2:
            per_ok = false
            continue
        var half := 0.0
        for k in range(1, sw.size()):
            half += float(sw[k]) - float(sw[k - 1])
        half /= float(sw.size() - 1)
        per_txt.append("%.2f" % (half * 2.0))
        if half * 2.0 < 1.55 or half * 2.0 > 2.45:
            per_ok = false
        phases["%.1f" % float(sw[0])] = true
    check("每条船一圈 1.6～2.4 秒（量到 %s 秒）、两种位置都到过" % str(per_txt), per_ok)
    check("5 条船不同步（起提时刻有 %d 种）" % phases.size(), phases.size() >= 4)

    print("3 降级")
    var cfg_density := 0.05
    var gl = glints[0]
    Ambient.level = 2
    gl._process(0.0)
    var d2: float = float(gl.material.get_shader_parameter("density"))
    Ambient.level = 1
    gl._process(0.0)
    var d1: float = float(gl.material.get_shader_parameter("density"))
    var v1: bool = gl.visible
    Ambient.level = 0
    gl._process(0.0)
    var v0: bool = gl.visible
    check("2 档亮的机会 %.3f（配置 %.2f）、1 档 %.3f（减半 %.3f）、1 档还看得见（%s）、0 档藏掉（%s）" % [d2, cfg_density, d1, cfg_density * 0.5, str(v1), str(not v0)], is_equal_approx(d2, cfg_density) and is_equal_approx(d1, cfg_density * 0.5) and v1 and not v0)
    var back := true
    Ambient.level = 0
    for step in 60:
        bb._process(dt)
    for i in bb.boats.size():
        if (bb.boats[i]["s"] as Sprite2D).offset.y != o0[i]:
            back = false
    check("0 档：5 条船都回原位", back)
    Ambient.level = 1
    var moved1 := false
    for step in int(6.0 / dt):
        bb._process(dt)
        for i in bb.boats.size():
            if (bb.boats[i]["s"] as Sprite2D).offset.y != o0[i]:
                moved1 = true
    check("1 档船照常起伏", moved1)
    Ambient.set_forced(-1)
    m._show_canvas("court")
    m._goto("court")
    await frames(3)
    check("切去迎宾院：湖边动效节点停（can_process %s）、波光也停（%s）" % [str(amb.can_process()), str(gl.can_process())], not amb.can_process() and not gl.can_process())
    m._show_canvas("lake")
    m._goto("lake")
    await frames(3)

    print("4 提示框跟月亮门牌子")
    var overlaps: Array = []
    var n := 0
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        for gate in ["to_garden", "to_orchard"]:
            for where in ["门里边", "门口"]:
                var pt: Dictionary = lk.points[gate]
                var at: Vector2 = lk.arrival_at(gate) if where == "门里边" else lk.nearest_free((pt["pos"] as Vector2) + Vector2(0, -20))
                lk.walking_enabled = true
                lk.reset_to(at)
                lk.cam.reset_smoothing()
                m.hint.visible = true
                await frames(6)
                var sv: SubViewport = m.view.get_child(0)
                var cc: Vector2 = lk.cam.get_screen_center_position()
                var z: float = lk.cam.zoom.x
                var scale_w := Vector2(get_root().size) / Vector2(sv.size)
                var hr: Rect2 = m.hint.get_global_rect()
                for lb in lk.labels.get_children():
                    if not lb is Label:
                        continue
                    var l := lb as Label
                    var home_x: float = float(l.get_meta("home")) if l.has_meta("home") else l.position.x
                    var a := ((Vector2(home_x, l.position.y) - cc) * z + Vector2(sv.size) * 0.5) * scale_w
                    var b2 := ((Vector2(home_x, l.position.y) + l.size - cc) * z + Vector2(sv.size) * 0.5) * scale_w
                    var lr := Rect2(a, b2 - a)
                    if not (Rect2(Vector2.ZERO, Vector2(sz)).intersects(lr)):
                        continue
                    n += 1
                    if lr.intersects(hr):
                        overlaps.append("%dx%d 站在 %s %s：牌「%s」%s 压提示框 %s" % [sz.x, sz.y, gate, where, l.text, str(lr), str(hr)])
                m.hint.visible = false
    get_root().size = Vector2i(540, 960)
    for x in overlaps.slice(0, 6):
        print("    ", x)
    check("提示框开着，两道月亮门里边和门口（手机、长屏），屏幕里看得到的牌子 %d 次量到，压提示框 %d 处" % [n, overlaps.size()], n >= 8 and overlaps.is_empty())

    DirAccess.remove_absolute("user://test_alcheck_court.json")
    DirAccess.remove_absolute("user://test_alcheck_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
