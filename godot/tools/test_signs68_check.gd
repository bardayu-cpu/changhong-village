extends SceneTree
## 第 68 版全游戏「去…」「回…」路牌加箭头（07 做，阿鱼：往上、往左放字前，往右、往下放字后），03 自己重测（01 H 10/4 派，不改游戏代码；不用 07 的 sign_target / edge_of）：
##   1 数：十四块里带箭头的路牌共 52 块；所有「去…」「回…」牌、楼门、大门牌都带箭头；迎宾院里不是出口的牌（回忆册、休息区…）、房间门牌（宴会厅的后厅、后花园、后厅四间屋）不带
##   2 写法：往上、往左的箭头在字前（「↑ 去果园」「← 去草坪」）、往右、往下的在字后（「去停车场 →」「去前门 ↓」）；箭头只有 ↑ ← → ↓ 四种
##   3 方向对：我自己认每块牌通哪个口（从牌上的字认通哪块，同名有几个口取离牌子最近的；「楼门」认宴会厅、「大门」认迎宾院大门），
##     口在这块走路范围的哪一侧（离走路范围中心最远的那个方向，跟 03 的连法测试同一个量法），箭头必须跟它一样；不一样的列出来，
##     再核一条硬的：从走路范围中心往箭头那边走口更近（点积 > 0）。牌子画在口的里边还是外边、走进口的最后一段路朝哪，只列出来、不判
##     （湖边、果园南边的牌子画在口外面，玩家在里边照样看得见；找路的拐点连线有时沿着墙边横着走到口）
##   4 同一块里，牌子两两不叠；牌子在画布里、不盖出生点、口、落点上站的人（40×90）
## 用法：Godot --headless --path . --script res://tools/test_signs68_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 30.0
const DIRV := {"↑": Vector2(0, -1), "↓": Vector2(0, 1), "←": Vector2(-1, 0), "→": Vector2(1, 0)}
const NAMES := {"court": ["迎宾院"], "banquet": ["宴会厅", "楼门"], "backhall": ["后厅"], "lawn": ["草坪"], "plaza": ["广场"], "kids": ["儿童乐园"], "shop": ["小卖部"],
    "rest2": ["休息厅"], "wkitchen": ["西餐厨房"], "garden": ["后花园"], "parking": ["停车场"], "frontgate": ["前门"], "lake": ["湖边"], "orchard": ["果园"], "backgate": ["后门"]}

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(200.0).timeout.connect(func():
        print("RESULT FAIL 200 秒没跑完")
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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func canvas_of(k: String):
    if k == "court":
        return m.court
    return m._canvas_by(k)

func go_canvas(k: String) -> void:
    m.switching = false
    m._show_canvas(k)
    m._goto(k)
    m.cv.walking_enabled = true
    m.cv.stick = Vector2.ZERO
    m.cv.path.clear()

func walk_rect(c) -> Rect2:
    var lo := Vector2(INF, INF)
    var hi := Vector2(-INF, -INF)
    for poly in c.cfg["walk"]:
        for v in poly:
            lo = Vector2(minf(lo.x, float(v[0])), minf(lo.y, float(v[1])))
            hi = Vector2(maxf(hi.x, float(v[0])), maxf(hi.y, float(v[1])))
    return Rect2(lo, hi - lo)

func side_dir(c, p: Vector2) -> String:
    var r := walk_rect(c)
    var n := (p - r.get_center()) / (r.size * 0.5)
    if absf(n.x) > absf(n.y):
        return "→" if n.x > 0.0 else "←"
    return "↓" if n.y > 0.0 else "↑"

func arrow_of(t: String) -> String:
    for a in DIRV:
        if t.contains(a):
            return a
    return ""

## 牌子通哪个口：从牌上的字认通哪块；认不出的（楼门、大门）单独处理
func target_of(c, k: String, text: String, at: Vector2) -> Vector2:
    var base := text
    for a in DIRV:
        base = base.replace(a, "")
    base = base.strip_edges()
    var want_to := ""
    for to in NAMES:
        for w in NAMES[to]:
            if base.contains(w) and want_to == "":
                want_to = to
    if base == "大门" or (k == "court" and want_to == "parking"):
        return c.spot_pos("gate") if k == "court" else Vector2.ZERO   # 第 68 版迎宾院没有去停车场的口了，大门出去就是停车场
    var best := Vector2.ZERO
    var bd := INF
    for id in c.points:
        if str(c.points[id]["to"]) == want_to:
            var d: float = at.distance_to(c.points[id]["pos"])
            if d < bd:
                bd = d
                best = c.points[id]["pos"]
    if best == Vector2.ZERO and want_to == "banquet" and k == "court":
        return c.points["to_hall"]["pos"] if c.points.has("to_hall") else Vector2.ZERO
    return best

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_sg68_court.json"
    m.games_save.local_path = "user://test_sg68_games.json"
    var keys: Array = ["court", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        if k != "court":
            m.ensure_canvas(k)
    await m._enter_court()
    m.dialog.visible = false

    print("1、2 数、写法")
    var total_arrow := 0
    var no_arrow_exit: Array = []
    var bad_arrow_label: Array = []
    var bad_pos: Array = []
    var rows: Array = []   # [canvas, text, arrow, label_center, target]
    for k in keys:
        var c = canvas_of(k)
        for lb in c.labels.get_children():
            if not lb is Label:
                continue
            var l := lb as Label
            var t := str(l.text)
            var a := arrow_of(t)
            var base := t
            for ar in DIRV:
                base = base.replace(ar, "")
            base = base.strip_edges()
            var is_exit: bool = base.begins_with("去") or base.begins_with("回") or base in ["楼门", "大门"]
            var center: Vector2 = l.position + l.size * 0.5
            if a != "":
                total_arrow += 1
                rows.append([k, t, a, center, target_of(c, k, t, center)])
                var pre: bool = t.begins_with(a)
                var suf: bool = t.ends_with(a)
                var want_pre: bool = a == "↑" or a == "←"
                if (want_pre and not pre) or (not want_pre and not suf):
                    bad_pos.append("%s「%s」箭头位置不对（%s 该在字%s）" % [k, t, a, "前" if want_pre else "后"])
                var n_ar := 0
                for ch in t:
                    if DIRV.has(str(ch)):
                        n_ar += 1
                if n_ar != 1:
                    bad_arrow_label.append("%s「%s」有 %d 个箭头" % [k, t, n_ar])
            elif is_exit:
                no_arrow_exit.append("%s「%s」" % [k, t])
    for x in bad_pos + bad_arrow_label + no_arrow_exit:
        print("    ", x)
    check("十四块带箭头的路牌共 %d 块（07 说 52）；「去…」「回…」「楼门」「大门」牌都带箭头（没带的 %d 块）" % [total_arrow, no_arrow_exit.size()], total_arrow == 52 and no_arrow_exit.is_empty())
    check("往上、往左的箭头在字前，往右、往下的在字后，每块牌一个箭头（%d 处不对）" % (bad_pos.size() + bad_arrow_label.size()), bad_pos.is_empty() and bad_arrow_label.is_empty())
    var h = m.hall
    var hall_arrow := 0
    for hs in h.room_signs:
        var lbl = (hs as Node2D).get_child(0)
        if lbl is Label and arrow_of(str((lbl as Label).text)) != "":
            hall_arrow += 1
    var bh_arrow := 0
    for hs in m.backhall.room_signs:
        var lbl2 = (hs as Node2D).get_child(0)
        if lbl2 is Label and arrow_of(str((lbl2 as Label).text)) != "":
            bh_arrow += 1
    check("房间门牌（宴会厅后厅 / 后花园、后厅四间屋）不带箭头（%d、%d 块带了）" % [hall_arrow, bh_arrow], hall_arrow == 0 and bh_arrow == 0)

    print("3 方向对")
    var diff: Array = []
    var half_bad: Array = []
    var last_bad: Array = []
    var no_target: Array = []
    var outside: Array = []
    for r in rows:
        var k: String = r[0]
        var c = canvas_of(k)
        var tgt: Vector2 = r[4]
        if tgt == Vector2.ZERO:
            no_target.append("%s「%s」认不出通哪个口" % [k, r[1]])
            continue
        var mine := side_dir(c, tgt)
        var wr := walk_rect(c)
        var d: Vector2 = DIRV[r[2]]
        if mine != r[2]:
            diff.append("%s「%s」：箭头 %s，我量口 %s 在走路范围的 %s 侧" % [k, r[1], r[2], str(tgt), mine])
        if (tgt - wr.get_center()).dot(d) <= 0.0:
            half_bad.append("%s「%s」：从走路范围中心往 %s 走，口 %s 反而更远" % [k, r[1], r[2], str(tgt)])
        if (tgt - (r[3] as Vector2)).dot(d) <= 0.0:
            outside.append("%s「%s」画在口 %s 的外边（从牌子往 %s 走口更远）" % [k, r[1], str(tgt), r[2]])
        # 从走路范围中心走到口，最后一段路的方向
        var from: Vector2 = c.nearest_free(wr.get_center())
        if from == Vector2.ZERO:
            from = c.SPAWN
        var path: Array = c.find_path(from, tgt)
        if path.size() >= 2:
            var seg: Vector2 = (path[path.size() - 1] as Vector2) - (path[path.size() - 2] as Vector2)
            var seg_dir := "→" if absf(seg.x) > absf(seg.y) and seg.x > 0.0 else ("←" if absf(seg.x) > absf(seg.y) else ("↓" if seg.y > 0.0 else "↑"))
            if seg.length() > 12.0 and seg_dir != r[2]:
                last_bad.append("%s「%s」：走进口 %s 的最后一段朝 %s（%s），箭头是 %s" % [k, r[1], str(tgt), seg_dir, str(seg), r[2]])
    for x in no_target + diff + half_bad:
        print("    ", x)
    print("    注：牌子画在口外边的有 %d 块 %s" % [outside.size(), str(outside.map(func(x): return str(x).split("（")[0]))])
    check("每块牌都认得出通哪个口（认不出 %d 块）" % no_target.size(), no_target.is_empty())
    check("箭头跟我量的口所在侧一样（不一样 %d 块）" % diff.size(), diff.is_empty())
    print("    注：走进口的最后一段（找路拐点连线）朝的方向跟箭头不一样的 %d 块（路是沿着墙边横着走到口的，不算）" % last_bad.size())
    check("从走路范围中心往箭头那边走口更近（%d 块反了）" % half_bad.size(), half_bad.is_empty())

    print("4 不叠、不盖人")
    var over_lab: Array = []
    var out_lab: Array = []
    var over_p: Array = []
    for k in keys:
        var c = canvas_of(k)
        var rs: Array = []
        for lb in c.labels.get_children():
            if lb is Label:
                var l := lb as Label
                var home_x: float = float(l.get_meta("home")) if l.has_meta("home") else l.position.x
                rs.append([str(l.text), Rect2(Vector2(home_x, l.position.y), l.size)])
        var cw := float(c.cfg["size"][0])
        var ch := float(c.cfg["size"][1])
        for i in rs.size():
            var ri: Rect2 = rs[i][1]
            if ri.position.x < -2.0 or ri.position.y < -2.0 or ri.end.x > cw + 2.0 or ri.end.y > ch + 2.0:
                out_lab.append("%s「%s」出画布 %s" % [k, rs[i][0], str(ri)])
            for j in range(i + 1, rs.size()):
                if ri.intersects(rs[j][1]):
                    over_lab.append("%s「%s」×「%s」" % [k, rs[i][0], rs[j][0]])
        var spots: Array = [c.SPAWN]
        for pid in c.points:
            if str(c.points[pid]["to"]) != "":
                spots.append(c.points[pid]["pos"])
                spots.append(c.arrival_at(pid))
        for rr in rs:
            for sp in spots:
                var body := Rect2((sp as Vector2).x - 20.0, (sp as Vector2).y - 90.0, 40.0, 90.0)
                if (rr[1] as Rect2).intersects(body):
                    over_p.append("%s「%s」盖 %s 站的人" % [k, rr[0], str(sp)])
    for x in over_lab + out_lab + over_p:
        print("    ", x)
    check("同一块里牌子两两不叠（%d 对）、都在画布里（%d 块出去）、不盖出生点 / 口 / 落点上站的人（%d 处）" % [over_lab.size(), out_lab.size(), over_p.size()], over_lab.is_empty() and out_lab.is_empty() and over_p.is_empty())

    DirAccess.remove_absolute("user://test_sg68_court.json")
    DirAccess.remove_absolute("user://test_sg68_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
