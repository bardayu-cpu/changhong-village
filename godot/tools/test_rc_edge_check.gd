extends SceneTree
## 走到头那一句真的看得见吗（庄Z3，10/6 复测 rc-makeup c2f62fe；庄Z1 派：「走到头提示 16 张画布都出」）。
## 话泡改成「先保不叠再守禁区、放不下先不显示」以后，走到头的小气泡（edge_bubble）也走同一套摆法，可能被整只藏掉。
## test_liantu_extra_check 只数「弹没弹」（信号和气泡节点），不看屏上看不看得见——这份补这一块：
##   每块画布（court、后厅、草坪、湖边、果园、停车场、广场、儿童乐园、小卖部、休息区 2、西餐厨房、后花园、前门、后门、化妆间；宴会厅有这个信号也量）
##   × 四个方向 × 每个方向两处（最靠那一边的点、中间的点；都是「推过去前面 30 像素没有能走的地」的真走到头）
##   × 手机 540×960 和长屏 585×1266：真推摇杆顶着不放，让游戏自己的帧跑几帧，量气泡：
##   弹了、节点在、visible、整只框在屏里（四边 16、顶栏线 safe_top 以下）、离人不太远（框中心离人 ≤ 屏高的 40%）
## 时限：600
## 用法：Godot --headless --path . --script res://tools/test_rc_edge_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DialogSkin = preload("res://scripts/ui/dialog_skin.gd")
const DT := 1.0 / 60.0
var m
var started := false
var ok := true
var bumps := 0

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(840.0).timeout.connect(func():
        print("RESULT FAIL 840 秒没跑完")
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

func canvas_of(k: String):
    if k == "court":
        return m.court
    if k == "banquet":
        return m.hall
    return m._canvas_by(k)

func go_canvas(k: String) -> void:
    m.switching = false
    m._show_canvas(k)
    m._goto(k)
    m.cv.walking_enabled = true
    m.cv.stick = Vector2.ZERO
    m.cv.path.clear()

func cpos(c, i: int, j: int) -> Vector2:
    return Vector2((float(i) + 0.5) * float(c.cell), (float(j) + 0.5) * float(c.cell))

func node_rect(n: CanvasItem, r: Rect2) -> Rect2:
    var xf: Transform2D = n.get_global_transform_with_canvas()
    var a: Vector2 = xf * r.position
    var b: Vector2 = xf * r.end
    return Rect2(a, b - a).abs()

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.court_save.local_path = "user://test_rce_court.json"
    m.games_save.local_path = "user://test_rce_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    var keys: Array = ["court", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        if k != "court":
            m.ensure_canvas(k)
    await m._enter_court()
    m.dialog.visible = false
    if m.hall != null and m.hall.has_signal("edge_bump") and m.hall.get("cfg") != null:
        keys.append("banquet")
    for k in keys:
        canvas_of(k).edge_bump.connect(func(_d): bumps += 1)
    print("共 %d 块画布：%s" % [keys.size(), str(keys)])

    var DIRS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
    var bad: Array = []
    var runs := 0
    var no_bump := 0
    var seen_modes := {}
    var per_canvas := {}   # 块 -> 量了几处
    var far_max := 0.0
    var top_rows: Array = []   # 往上顶到最上沿那几处的数
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        var vs := Vector2(sz)
        for k in keys:
            var c = canvas_of(k)
            var exit_ps: Array = []
            for pid in c.points:
                if str(c.points[pid]["to"]) != "":
                    exit_ps.append(c.points[pid]["pos"])
            for dn in DIRS:
                var d: Vector2 = DIRS[dn]
                var cands: Array = []
                for j in range(2, c.rows - 2):
                    for i in range(2, c.cols - 2):
                        var p := cpos(c, i, j)
                        if not c._free(p) or c._free(p + d * 12.0):
                            continue
                        var near_exit := false
                        for e in exit_ps:
                            if p.distance_to(e) < 260.0:
                                near_exit = true
                        if near_exit or p.distance_to(c.SPAWN) < 80.0:
                            continue
                        cands.append(p)
                if cands.is_empty():
                    continue
                cands.sort_custom(func(a, b): return a.dot(d) > b.dot(d))   # 最靠 d 那一边的在前
                # 先试推一次：人停下来以后前面 30、60 像素都没有能走的地 = 真走到头；有 = 被家具、花坛、墙挡着，不算
                var picks: Array = []
                var tried := 0
                var starts: Array = [0, int(float(cands.size() - 1) * 0.5)]
                for st in starts:
                    var from_i: int = st
                    var got := false
                    var last_try := Vector2(-9999, -9999)
                    for ci in range(from_i, cands.size()):
                        var q: Vector2 = cands[ci]
                        if q.distance_to(last_try) < 30.0:
                            continue
                        last_try = q
                        tried += 1
                        if tried > 60:
                            break
                        go_canvas(k)
                        c.reset_to(q)
                        tick(3)
                        c.stick = d
                        tick(60)
                        c.stick = Vector2.ZERO
                        var stop: Vector2 = c.pos
                        if not (c.in_walk(stop + d * 30.0) or c.in_walk(stop + d * 60.0)):
                            if not picks.has(q):
                                picks.append(q)
                            got = true
                            break
                    if got and picks.size() >= 2:
                        break
                for p0 in picks:
                    go_canvas(k)
                    c.reset_to(c.SPAWN)
                    tick(3)
                    c.reset_to(p0)
                    c.snap_cam()
                    m.dialog.visible = false
                    tick(2)
                    await frames(2)
                    bumps = 0
                    c.stick = d
                    var shown_at := -1
                    for step in int(4.0 / DT):
                        tick(1)
                        if bumps > 0:
                            shown_at = step
                            break
                    c.stick = Vector2.ZERO
                    runs += 1
                    per_canvas[k] = int(per_canvas.get(k, 0)) + 1
                    var tag := "%dx%d %s 往%s 在 (%d,%d)" % [sz.x, sz.y, k, dn, int(p0.x), int(p0.y)]
                    if shown_at < 0:
                        no_bump += 1
                        bad.append("%s：顶了 4 秒没弹" % tag)
                        continue
                    await frames(4)   # 游戏自己的帧：话泡摆法在节点的 _process 里
                    var bubs: Array = get_nodes_in_group("edge_bubble")
                    var b: Node2D = null
                    for x in bubs:
                        if is_instance_valid(x) and not (x as Node).is_queued_for_deletion():
                            b = x
                    if b == null:
                        bad.append("%s：弹了但气泡节点不在" % tag)
                        continue
                    var sk = b.get_node_or_null("safe_keep")
                    var mode: String = str(sk.mode) if sk != null else "-"
                    seen_modes[mode] = int(seen_modes.get(mode, 0)) + 1
                    if not b.visible or not b.is_visible_in_tree():
                        bad.append("%s：弹了但气泡被藏起来了（放法 %s）" % [tag, mode])
                        continue
                    var box: Control = null
                    for c2 in b.get_children():
                        if c2 is Control:
                            box = c2
                            break
                    if box == null:
                        bad.append("%s：气泡里找不到框" % tag)
                        continue
                    var r: Rect2 = node_rect(box, Rect2(Vector2.ZERO, box.size))
                    var lo_y: float = maxf(15.5, float(DialogSkin.safe_top) - 0.5)
                    if r.position.x < 15.5 or r.end.x > vs.x - 15.5 or r.position.y < lo_y or r.end.y > vs.y - 15.5:
                        bad.append("%s：气泡框 %s 不在屏里（四边 16、顶栏线 %.0f 以下；放法 %s）" % [tag, str(r), DialogSkin.safe_top, mode])
                    var person: Vector2 = c.get_viewport().get_canvas_transform() * c.pos
                    var far: float = r.get_center().distance_to(person)
                    far_max = maxf(far_max, far)
                    if far > vs.y * 0.4:
                        bad.append("%s：气泡离人太远（框中心离人 %.0f 像素，放法 %s）" % [tag, far, mode])
                    if dn == "up" and p0 == cands[0]:
                        top_rows.append("%s %s 脚离屏顶 %.0f 放法 %s" % [k, str(sz.x), person.y, mode])
                    # 让它走完（1.6 秒的真时间），别带到下一处
                    for q in 3:
                        await frames(1)
                    for x in get_nodes_in_group("edge_bubble"):
                        if is_instance_valid(x):
                            if x.get_parent() != null:
                                x.get_parent().remove_child(x)
                            x.queue_free()
    get_root().size = Vector2i(540, 960)
    print("    共量了 %d 处；每块画布量到的处数：%s" % [runs, str(per_canvas)])
    print("    气泡放法分布：%s；框中心离人最远 %.0f 像素" % [str(seen_modes), far_max])
    print("    往上顶到最上沿的（每块每屏一处）：%s" % str(top_rows))
    for x in bad.slice(0, 12):
        print("    ", x)
    check("%d 块画布都量到了（没量到的：%s）" % [per_canvas.size(), str(keys.filter(func(k): return not per_canvas.has(k)))], per_canvas.size() >= 14)
    check("走到头那一句：%d 处顶着推，都弹了、看得见、整只框在屏里和顶栏线下、离人不太远（%d 处不对）" % [runs, bad.size()], bad.is_empty() and runs >= 100)
    DirAccess.remove_absolute("user://test_rce_court.json")
    DirAccess.remove_absolute("user://test_rce_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
