extends SceneTree
## 验收：全山庄连图（01 G 10/4 派，godot/回执/派活-连图灰盒-1004.md）。无界面跑整个 main.gd。
##   1 每一块的每个口（布局里写了 to 的）：站到口里边 → 推着走进口子 → 到了对面那块、站在对面通回来的那个口里边 → 站 60 帧不弹回去 →
##     再走对面那个口回来，回到原来那块。迎宾院大门（走 _at_gate）、宴会厅三道门另测
##   2 走到头：推着摇杆往没路的那边顶住，弹一句；一直顶着不重复弹；走开再回来才再弹；点画布外头也弹。
##     （05 10/4 新规矩：走到头那句改成人头顶冒一个小气泡 edge_bubble，停 1.6 秒，同一时间只留一个，不再写顶上提示条）
##   3 自动开车：前门 → 喷泉广场 → 停车场三段都开过，停好以后人在自己车旁、自己的车在车位上；第二次点一下就跳过
##   4 湖边：南墙外、码头这些看着是地面的能走；船夫 1 跟前有能站的地方
##   5 牌子不盖人：每块画布的「去…」牌，跟站在口上、落点上、出生点上的人不叠
## 用法：Godot --headless --path . --script res://tools/test_liantu.gd     最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_liantu_court.json"

var m
var started := false
var ok := true
var bumps := 0

func _initialize() -> void:
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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func settle() -> void:
    for i in 60:
        if not m.switching:
            break
        await process_frame

## 推着走到某点（切了画布就停）
func walk_to(target: Vector2, secs := 25.0) -> void:
    var c = m.cv
    c.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv != c or c.path.is_empty():
            break
    await settle()

func canvas_of(k: String):
    if k == "court":
        return m.court
    if k == "banquet":
        return m.hall
    return m._canvas_by(k)

func go_canvas(k: String) -> void:
    m._show_canvas(k)
    m._goto(k)
    m.cv.walking_enabled = true

## 落点：走 a 那块的 pid 那个口到了 to 那块，应该站哪
func expect_at(a: String, pt: Dictionary, to: String) -> Vector2:
    var t = canvas_of(to)
    if str(pt["via"]) != "":
        return t.arrival_at(str(pt["via"]))
    var at: Vector2 = t.arrival_from(a)
    if at == Vector2.ZERO and to == "court":
        return m.court.SPAWN   # 前门北口进迎宾院大门（迎宾院那头是大门 gate，不写 to）
    return at

## 对面通回来的那个口
func back_point(to: String, a: String, pt: Dictionary) -> String:
    var t = canvas_of(to)
    for id in t.points:
        if str(t.points[id]["to"]) == a and (str(pt["via"]) == "" or id == str(pt["via"])):
            return id
    return ""


## 走到头的小气泡（05 10/4：不再写顶上那条，改成人头顶冒一个小气泡，画布上叫 edge_bubble，话在它的 Label 里，停 1.6 秒）
func edge_nodes(c) -> Array:
    # 05 的 main._on_edge_bump 先 queue_free 旧的再加新的，新的会因为重名被改成「@Node2D@数字」，所以不能只认名字 edge_bubble：
    # 名字以 edge_bubble 开头、或者里头有一个 Label 写着走到头那句话的，都算（没删的）
    var texts: Array = []
    for dn in ["up", "down", "left", "right"]:
        texts.append(CourtCopy.text("edge_" + dn, CourtCopy.AREAS))
    var out: Array = []
    for n in c.get_children():
        if not (n is Node2D) or n.is_queued_for_deletion():
            continue
        var hit: bool = str(n.name).begins_with("edge_bubble")
        if not hit:
            for lb in (n as Node).find_children("*", "Label", true, false):
                if str((lb as Label).text) in texts:
                    hit = true
        if hit:
            out.append(n)
    return out

func edge_text(c) -> String:
    for n in edge_nodes(c):
        for lb in (n as Node).find_children("*", "Label", true, false):
            return str((lb as Label).text)
    return ""

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify({"welcomed": true, "signed_in": true}))
    f.close()
    m.court_save.local_path = SAVE
    m.court_save.load_local()
    m.games_save.local_path = "user://test_liantu_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    var keys: Array = ["court", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        if k != "court":
            m.ensure_canvas(k)
    await m._enter_court()
    m.dialog.visible = false
    for k in keys:
        canvas_of(k).edge_bump.connect(func(_d): bumps += 1)

    print("1 每个口来回走")
    var links := 0
    var bad: Array = []
    for k in keys:
        var c = canvas_of(k)
        for pid in c.points:
            var pt: Dictionary = c.points[pid]
            var to := str(pt["to"])
            if to == "" or to == "banquet":
                continue
            links += 1
            go_canvas(k)
            c.reset_to(c.arrival_at(pid))
            m.dialog.visible = false
            tick(3)
            await walk_to(pt["pos"])
            if m.state != to:
                bad.append("%s.%s → %s 没到（在 %s %s）" % [k, pid, to, m.state, m.cv.pos])
                continue
            var t = m.cv
            var want := expect_at(k, pt, to)
            if t.pos.distance_to(want) > 1.0:
                bad.append("%s.%s → %s 站在 %s，该站 %s" % [k, pid, to, t.pos, want])
            tick(60)
            if m.state != to:
                bad.append("%s.%s → %s 站着弹回去了" % [k, pid, to])
                continue
            var bid := back_point(to, k, pt)
            if bid == "":
                if to == "court":
                    await walk_to(m.court.SPAWN + Vector2(0, -120))   # 进来站在大门圈里：先走开，再回大门
                    await walk_to(m.court.spot_pos("gate"))   # 迎宾院大门出去回到刚才那块（第 68 版 07：大门通停车场，原来通前门）
                    if m.state != k or k != "parking":
                        bad.append("迎宾院大门没回停车场（从 %s 来，现在在 %s）" % [k, m.state])
                    continue
                bad.append("%s 没有通回 %s 的口" % [to, k])
                continue
            await walk_to(t.points[bid]["pos"])
            if m.state != k:
                bad.append("%s.%s 走回去没回到 %s（在 %s）" % [to, bid, k, m.state])
    for b in bad:
        print("    ", b)
    check("%d 个口来回都通、落点对、不弹回去" % links, bad.is_empty() and links >= 40)

    print("1b 宴会厅三道门（方案 C：西侧门通后厅、东侧门通后花园）")
    go_canvas("garden")
    var g = m.areas["garden"]
    g.reset_to(g.arrival_at("to_banquet"))
    tick(3)
    await walk_to(g.points["to_banquet"]["pos"])
    check("后花园西口进宴会厅，站在东侧门里边 %s" % m.hall.pos, m.state == "banquet" and m.hall.pos == Vector2(1456, 1289))
    tick(60)
    check("站着不弹回后花园", m.state == "banquet")
    await walk_to(Vector2(1516, 1289))
    check("宴会厅东侧门出去回后花园，站在西口里边", m.state == "garden" and g.pos.distance_to(g.arrival_from("banquet")) < 1.0)
    # 方案 C：宴会厅西墙那道门通后厅（化妆间挨着宴会厅）
    go_canvas("backhall")
    var bh = m.backhall
    bh.reset_to(bh.arrival_at("to_hall"))
    tick(3)
    await walk_to(bh.points["to_hall"]["pos"])
    check("后厅走廊东头进宴会厅，站在西侧门里边 %s" % m.hall.pos, m.state == "banquet" and m.hall.pos == Vector2(104, 1300))
    tick(60)
    check("站着不弹回后厅", m.state == "banquet")
    await walk_to(Vector2(40, 1300))
    check("宴会厅西侧门出去回后厅，站在走廊东头里边", m.state == "backhall" and bh.pos.distance_to(bh.arrival_from("banquet")) < 1.0)

    print("2 走到头")
    go_canvas("plaza")
    var p = m.plaza
    p.reset_to(Vector2(320, 240))
    tick(3)
    bumps = 0
    p.stick = Vector2(0, -1)
    tick(90)
    var first := bumps
    var txt: String = edge_text(p)
    var live1: int = edge_nodes(p).size()
    tick(90)
    p.stick = Vector2.ZERO
    tick(2)
    check("往北顶到绿篱：头顶冒一个小气泡「%s」（%d 个），一直顶着不重复（%d 次）" % [txt, live1, bumps], first == 1 and bumps == 1 and txt == "这边过不去了" and live1 == 1)   # 10/4 04 看第 65 版：走到头统一一句不分方向
    check("不再写顶上提示条（提示条显示 %s、字「%s」）" % [str(m.note_box.visible), m.note.text], not m.note_box.visible and m.note.text != "这边过不去了")
    p.reset_to(Vector2(320, 360))
    tick(3)
    p.reset_to(Vector2(320, 240))
    p.stick = Vector2(0, -1)
    tick(60)
    p.stick = Vector2.ZERO
    var live2: int = edge_nodes(p).size()
    check("走开再回来顶又弹（%d 次），同一时间只留一个小气泡（%d 个）" % [bumps, live2], bumps == 2 and live2 == 1)
    p.reset_to(Vector2(1300, 860))
    tick(3)
    p.stick = Vector2(1, 0)
    tick(60)
    p.stick = Vector2.ZERO
    check("往东顶也弹同一句：「%s」" % edge_text(p), bumps == 3 and edge_text(p) == "这边过不去了")
    p.reset_to(Vector2(700, 300))
    tick(3)
    p.tap(p.get_viewport().get_canvas_transform() * Vector2(700, 120))
    tick(2)
    var live4: int = edge_nodes(p).size()
    check("点绿篱外头的草地也弹（%d 次）；连着弹 4 次（都在 2 秒内）同一时间还是只留一个小气泡（%d 个）" % [bumps, live4], bumps == 4 and live4 == 1)
    p.path.clear()
    var nb := bumps
    p.reset_to(Vector2(300, 600))
    p.stick = Vector2(1, 0)
    tick(120)
    p.stick = Vector2.ZERO
    check("被花坛、长椅挡住不算走到头（%d 次）" % bumps, bumps == nb)

    print("3 自动开车")
    m.court_save.drive_seen = false
    m.drive_in_fast = true
    var legs: Array = []
    var tip_first := false
    var shown_while_driving := false   # 开车的时候摇杆或「点地面走路」露出来过
    m._drive_in()
    for i in 6000:
        await process_frame
        if m.drive.leg != "" and (legs.is_empty() or legs[-1] != m.drive.leg):
            legs.append(m.drive.leg)
        if not m.driving:
            break
        tip_first = tip_first or (m.drive.tip != null and m.drive.tip.visible)
        shown_while_driving = shown_while_driving or m.stick_base.visible or m.hint.visible
    for i in 60:
        await process_frame
        if m.state == "parking" and not m.switching:
            break
    var mine: Node = m.parking.world.get_node("car_mine")
    check("开过三段 %s，停好在停车场、人在自己车旁 %s" % [legs, m.parking.pos], legs == ["frontgate", "plaza", "parking"] and m.state == "parking"
        and m.parking.pos == m.parking.SPAWN and mine.visible and m.court_save.drive_seen and m.parking.player.visible)
    check("第一次开车：不出「点一下屏幕跳过」（%s），摇杆和「点地面走路」开车时都藏着（露出来过 %s）" % [tip_first, shown_while_driving], not tip_first and not shown_while_driving)
    legs.clear()
    m._drive_in()
    for i in 10:
        await process_frame
    var tip_text := ""
    if m.drive.tip != null and m.drive.tip.visible:
        tip_text = (m.drive.tip.get_child(0) as Label).text
    check("看过一次以后再开：屏幕上一行「%s」" % tip_text, tip_text == "点一下屏幕跳过")
    m.drive.skip()
    var n := 0
    for i in 6000:
        await process_frame
        n += 1
        if m.drive.leg != "" and (legs.is_empty() or legs[-1] != m.drive.leg):
            legs.append(m.drive.leg)
        if not m.driving:
            break
    for i in 60:
        await process_frame
        if m.state == "parking" and not m.switching:
            break
    check("看过一次点一下就跳过（只开了 %s，%d 帧），直接停车场下车" % [legs, n], legs.size() <= 1 and m.state == "parking" and mine.visible)
    m.drive_in_fast = false

    print("4 湖边")
    var lk = m.lake
    var free_ok := true
    for q in [Vector2(1000, 1150), Vector2(300, 1200), Vector2(2304, 1150), Vector2(2900, 1150), Vector2(908, 618), Vector2(840, 600), Vector2(768, 1080)]:   # 10/4 西半边接图：码头平台、西头月亮门门洞
        if not lk._free(q):
            free_ok = false
            print("    走不了 ", q)
    check("南墙外、码头、西头月亮门（去果园）都能走", free_ok)
    var bm: Vector2 = Vector2(908, 588)   # 西半边接图后船夫站在码头平台上
    check("船夫 1 跟前 72 像素内有能站的地方 %s" % lk.nearest_free(bm + Vector2(0, 30)), lk.nearest_free(bm + Vector2(0, 30)) != Vector2.ZERO
        and lk.nearest_free(bm + Vector2(0, 30)).distance_to(bm) < 72.0)

    print("5 牌子不盖人")
    var hits: Array = []
    for k in keys:
        var c = canvas_of(k)
        var spots: Array = [c.SPAWN]
        for id in c.points:
            if str(c.points[id]["to"]) != "":
                spots.append(c.points[id]["pos"])
                spots.append(c.arrival_at(id))
        for l in c.labels.get_children():
            if not l is Control or not (l as Control).visible:
                continue
            var home: float = float(l.get_meta("home")) if l.has_meta("home") else (l as Control).position.x
            var r := Rect2(Vector2(home, (l as Control).position.y), (l as Control).size)
            for s in spots:
                if r.intersects(Rect2((s as Vector2).x - 16.0, (s as Vector2).y - 84.0, 32.0, 84.0)):
                    hits.append("%s「%s」盖 %s" % [k, (l as Label).text, s])
    # 宴会厅两道侧门的门牌（layered_hall.room_sign，不在 labels 那层；03 测第 65 版报的）：不盖站在两道门落点上的人
    var hl = m.hall
    var hall_spots: Array = [hl.side_arrive]
    for e in hl.exits:
        hall_spots.append(e["arrive"])
    for sg in hl.room_signs:
        var lb: Label = (sg as Node2D).get_child(0)
        var rr := Rect2((sg as Node2D).position + lb.position, lb.size)
        for s in hall_spots:
            if rr.intersects(Rect2((s as Vector2).x - 16.0, (s as Vector2).y - 84.0, 32.0, 84.0)):
                hits.append("宴会厅门牌「%s」盖 %s" % [lb.text, s])
    for h in hits.slice(0, 8):
        print("    ", h)
    check("各块「去…」牌、宴会厅两块门牌都不盖站在口上、落点上、出生点上的人（盖了 %d 处）" % hits.size(), hits.is_empty())

    DirAccess.remove_absolute(SAVE)
    print("6 走到头的小气泡停 1.6 秒（真时间；放在最后量：这里等真时间，放前面会把后面的开车提示计时带歪）")
    go_canvas("plaza")
    var p5 = m.plaza
    p5.reset_to(Vector2(320, 360))
    tick(3)
    p5.reset_to(Vector2(320, 240))
    tick(3)
    p5.stick = Vector2(0, -1)
    tick(60)
    p5.stick = Vector2.ZERO
    var live_a: int = edge_nodes(p5).size()
    await create_timer(1.0).timeout
    var still: int = edge_nodes(p5).size()
    await create_timer(0.9).timeout
    var gone: int = edge_nodes(p5).size()
    check("弹出来 %d 个、1.0 秒时还在（%d 个）、1.9 秒时收了（%d 个）" % [live_a, still, gone], live_a == 1 and still == 1 and gone == 0)
    DirAccess.remove_absolute("user://test_liantu_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
