extends SceneTree
## 第 65 版（方案 C 整座山庄连图）里 02 没自己量的几样，03 补量（01 G 10/4 派，不改游戏代码）：
##   1 十四块画布（迎宾院、后厅、草坪、湖边、果园、停车场、广场、儿童乐园、小卖部、休息区 2、西餐厨房、后花园、前门、后门）：
##     走路范围里没被占地挡、却被圈掉不能站的格子（口袋），不比 03 记下的现状多；每个口、出生点、落点都能站、口的圈里有能站的格子
##   2 湖边：岸线以下（y 800～1270）看着是地面的格子，除了被占地挡的，都能走（逐格量，剩下的几格列出来）；码头、船夫跟前、小岛、曲桥、亭子前沿、南墙外这些点能站；
##     东头南墙月亮门去后花园、西头尽头去果园两个口能走到
##   3 走到头：十三块（宴会厅另算）每块、四个方向各找一处真走到头的地方（出口附近不算）推摇杆：弹一句（05 10/4 新规矩：人头顶冒一个小气泡 edge_bubble，话在它的 Label 里，不再写顶上提示条，同一时间只留一个）、一直顶着不重复、走开 ≥60 再回来才再弹；
##     被家具、花坛挡住的地方推不弹；点范围外弹、点家具上不弹；四句话统一成一句（10/4 01 G 定）
##   4 牌子：每块画布每一块牌，跟站在出生点、每个口上、每个落点上的人身子（40×90，比 02 量的 32×84 大一圈）一块不叠；牌子不出画布；
##     手机 540×960 和长屏 585×1266 下，人站在口上，对应「去…」牌整块在屏里；宴会厅的门牌跟进厅落点不叠（第 66 版起 0 处）
##   5 老的落点常量（main.gd 里没有对口的口时才用的兜底）站不站得了（只列，不判）
## 用法：Godot --headless --path . --script res://tools/test_liantu_extra_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const Ent = preload("res://scripts/entrance.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0
## 03 第 65 版量到的现状（口袋格数）：只守「不再多」。口袋 = 在走路范围多边形里、没被占地挡、却因为从出生点灌不到被圈掉的格子
const KNOWN_POCKETS := {"backhall": 46, "lawn": 6, "lake": 38}   # lake：10/4 西半边接图（02 E）多 26 格，在半岛柳树树冠底下（看不见的地）和亭子栏杆边角，截图核过
const LAKE_KNOWN_LEFT := 31   # 10/4 西半边接图（02 E）多 4 格：西头月亮门门洞两边的门柱（x 726、810，y 1026～1038），图里是墙，跟东头那道门一样

var m
var started := false
var ok := true
var bumps := 0

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
    return m._canvas_by(k)

func go_canvas(k: String) -> void:
    m.switching = false
    m._show_canvas(k)
    m._goto(k)
    m.cv.walking_enabled = true
    m.cv.stick = Vector2.ZERO
    m.cv.path.clear()

func polys_of(c) -> Array:
    var polys: Array = []
    for poly in c.cfg["walk"]:
        var pts := PackedVector2Array()
        for v in poly:
            pts.append(Vector2(float(v[0]), float(v[1])))
        polys.append(pts)
    return polys

func cpos(c, i: int, j: int) -> Vector2:
    return Vector2((float(i) + 0.5) * float(c.cell), (float(j) + 0.5) * float(c.cell))

## 递归找布局里含某个字的字符串（跳过 note、_ 开头的说明）
func find_text(v, word: String) -> Array:
    var out: Array = []
    if v is Dictionary:
        for k in v:
            if str(k) == "note" or str(k).begins_with("_"):
                continue
            out.append_array(find_text(v[k], word))
    elif v is Array:
        for x in v:
            out.append_array(find_text(x, word))
    elif v is String and (v as String).find(word) >= 0:
        out.append(str(v))
    return out


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
    m.court_save.local_path = "user://test_extra_court.json"
    m.games_save.local_path = "user://test_extra_games.json"
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

    print("1 口袋格子、口和落点能站")
    for k in keys:
        var c = canvas_of(k)
        var polys := polys_of(c)
        var pockets := 0
        var free_n := 0
        var pk_cells: Array = []
        for j in c.rows:
            for i in c.cols:
                var p := cpos(c, i, j)
                if c._free(p):
                    free_n += 1
                    continue
                var inside := false
                for pts in polys:
                    if Geometry2D.is_point_in_polygon(p, pts):
                        inside = true
                        break
                if inside and not Ent._blocked(p.x, p.y, c.obstacles, Ent.CLEAR):
                    pockets += 1
                    if pk_cells.size() < 3:
                        pk_cells.append(p)
        var bad_spots: Array = []
        if not c._free(c.SPAWN):
            bad_spots.append("出生点 %s 站不了" % str(c.SPAWN))
        for pid in c.points:
            var pt: Dictionary = c.points[pid]
            if str(pt["to"]) == "":
                continue
            var near_free := false
            for dy in range(-int(pt["r"]), int(pt["r"]) + 1, 6):
                for dx in range(-int(pt["r"]), int(pt["r"]) + 1, 6):
                    if Vector2(dx, dy).length() <= float(pt["r"]) and c._free((pt["pos"] as Vector2) + Vector2(dx, dy)):
                        near_free = true
            if not near_free:
                bad_spots.append("口 %s（%s，半径 %.0f）圈里没有能站的格子" % [pid, str(pt["pos"]), float(pt["r"])])
            var land: Vector2 = c.arrival_at(pid)
            if land == Vector2.ZERO or not c._free(land):
                bad_spots.append("落点 %s（走 %s 回来站的地方）%s 站不了" % [pid, pid, str(land)])
        print("  %s：能站的格子 %d 个，口袋 %d 格 %s" % [k, free_n, pockets, str(pk_cells)])
        for b in bad_spots:
            print("    ", b)
        check("%s 的出生点、每个口、每个落点都能站（%d 处不对）" % [k, bad_spots.size()], bad_spots.is_empty())
        check("%s 口袋 %d 格，不比 03 记下的现状 %d 格多" % [k, pockets, int(KNOWN_POCKETS.get(k, 0))], pockets <= int(KNOWN_POCKETS.get(k, 0)))

    print("2 湖边")
    var lk = m.lake
    var lk_polys := polys_of(lk)
    var left: Array = []
    for j in lk.rows:
        var y := (float(j) + 0.5) * float(lk.cell)
        if y < 800.0 or y > 1270.0:
            continue
        for i in lk.cols:
            var p := cpos(lk, i, j)
            if p.x < 60.0 or p.x > 3060.0:
                continue
            if not lk._free(p) and not Ent._blocked(p.x, p.y, lk.obstacles, Ent.CLEAR):
                left.append(p)
    var comp_max := 0
    var seen := {}
    for p in left:
        var key := Vector2i(int(p.x / lk.cell), int(p.y / lk.cell))
        if seen.has(key):
            continue
        var st: Array = [key]
        seen[key] = true
        var cnt := 0
        while not st.is_empty():
            var c0: Vector2i = st.pop_back()
            cnt += 1
            for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
                var n: Vector2i = c0 + d
                if not seen.has(n) and left.has(cpos(lk, n.x, n.y)):
                    seen[n] = true
                    st.append(n)
        comp_max = maxi(comp_max, cnt)
    print("    岸线以下（y 800～1270，x 60～3060）看着是地面、没被占地挡、却走不了的格子 %d 个，最大一块 %d 格 %s" % [left.size(), comp_max, str(left.filter(func(q): return q.x < 1536.0))])
    check("湖边岸线以下，除了被占地挡的，格子都能走（剩 %d 格，不比 03 记下的 %d 格多，最大一块 ≤ 9 格）" % [left.size(), LAKE_KNOWN_LEFT], left.size() <= LAKE_KNOWN_LEFT and comp_max <= 9)
    var stands := {
        "码头中间": Vector2(910, 700), "码头北头": Vector2(910, 600), "码头南头": Vector2(910, 780), "船夫 1 跟前": Vector2(910, 668),
        "小岛": Vector2(530, 560), "小岛下头": Vector2(530, 700), "岛上曲桥": Vector2(532, 760), "东头曲桥": Vector2(2305, 800),
        "亭子前沿": Vector2(2333, 646), "石板路西": Vector2(300, 820), "石板路东": Vector2(2000, 850), "南墙外西": Vector2(300, 1200),
        "南墙外中": Vector2(1000, 1150), "南墙外东": Vector2(2900, 1150), "东头月亮门里": Vector2(2304, 999), "南墙月亮门洞": Vector2(2304, 1050),
        "西头尽头": Vector2(60, 821), "渔夫 1 旁": Vector2(1170, 830), "长凳边": Vector2(1802, 860),
    }
    var cant: Array = []
    for k in stands:
        var sp: Vector2 = stands[k]
        var near: Vector2 = lk.nearest_free(sp)
        if not lk._free(sp) and (near == Vector2.ZERO or near.distance_to(sp) > 40.0):
            cant.append("%s %s 站不了（最近能站 %s）" % [k, str(sp), str(near)])
    for b in cant:
        print("    ", b)
    check("码头、船夫跟前、小岛、曲桥、亭子前沿、南墙外这些点 40 像素内能站（%d 处不行）" % cant.size(), cant.is_empty())
    var bm: Vector2 = Vector2(910, 640)
    var front: Vector2 = lk.nearest_free(bm + Vector2(0, 30))
    check("船夫 1（%s）跟前有能站的地方 %s（离 %.0f）" % [str(bm), str(front), front.distance_to(bm)], front != Vector2.ZERO and front.distance_to(bm) < 72.0)
    go_canvas("lake")
    var lres := {}
    for pid in ["to_garden", "to_orchard"]:
        go_canvas("lake")
        lk.reset_to(lk.SPAWN if pid == "to_garden" else lk.arrival_at("to_garden"))
        tick(3)
        var path: Array = lk.find_path(lk.pos, lk.points[pid]["pos"])
        lres[pid] = not path.is_empty()
    check("东头南墙月亮门（去后花园）、西头尽头（去果园）都有路走到 %s" % str(lres), lres["to_garden"] and lres["to_orchard"])

    print("3 走到头")
    var DIRS := {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}
    var texts := {}
    for dn in DIRS:
        texts[dn] = CourtCopy.text("edge_" + dn, CourtCopy.AREAS)
    var uniq := {}
    for dn in texts:
        uniq[texts[dn]] = true
    # 10/4 04 看第 65 版、01 G 定：走到头统一成一句不分方向的（「这边过不去了」），四个键还分着存
    check("四句话都有字、统一成一句 %s" % str(texts), uniq.size() == 1 and not (texts.values() as Array).has("edge_up") and str(texts["up"]) != "")
    var bump_bad: Array = []
    var multi_live := 0   # 同一时间留了不止一个小气泡的次数
    var note_wrote := 0   # 还往顶上提示条写字的次数
    var edge_n := 0
    var blocked_n := 0
    var skipped_rearm := 0
    var wall_known := 0
    var cover := {}   # 块 -> 量到的 [走到头几处, 被挡几处]
    for k in keys:
        var c = canvas_of(k)
        var exit_ps: Array = []
        for pid in c.points:
            if str(c.points[pid]["to"]) != "":
                exit_ps.append(c.points[pid]["pos"])
        var n_edge := 0
        var n_blk := 0
        for dn in DIRS:
            var d: Vector2 = DIRS[dn]
            # 往 d 这个方向的「边界格」：本格能站、前面 12 像素不能站
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
            var picks: Array = []
            for f in [0.2, 0.5, 0.8]:
                var q: Vector2 = cands[int(float(cands.size() - 1) * f)]
                if not picks.has(q):
                    picks.append(q)
            for p0 in picks:
                # 先试推一次，看人停在哪、前面 30、60 像素还有没有能走的地面：没有 = 地图的边（该弹）；有 = 墙、家具、花坛挡着、后面还有地（不该弹）
                go_canvas(k)
                c.reset_to(p0)
                m.dialog.visible = false
                tick(3)
                c.stick = d
                tick(60)
                c.stick = Vector2.ZERO
                var stop: Vector2 = c.pos
                var beyond: bool = c.in_walk(stop + d * 30.0) or c.in_walk(stop + d * 60.0)
                go_canvas(k)
                c.reset_to(c.SPAWN)   # 试推弹过的话留着「已经弹过」，走开 > 60 像素才重新上膛：先传到远处过一帧，再回来
                tick(3)
                c.reset_to(p0)
                tick(2)
                bumps = 0
                c.stick = d
                tick(int(1.5 / DT))
                var first := bumps
                var shown: String = edge_text(c)
                if edge_nodes(c).size() > 1:
                    multi_live += 1
                if m.note_box.visible and m.note.text == str(texts[dn]):
                    note_wrote += 1
                tick(int(1.5 / DT))
                var held := bumps
                c.stick = Vector2.ZERO
                tick(2)
                if beyond:
                    blocked_n += 1
                    n_blk += 1
                    if held != 0 and k == "lake" and p0.y > 1048.0 and d.y < 0.0:
                        wall_known += 1   # 湖边南墙（宽 12、两边各留 12 = 36 像素厚），从南墙外往北顶：墙后 30 像素处没有地面，弹「前面过不去了」，话是对的
                    elif held != 0:
                        bump_bad.append("%s 往%s 在 %s 被挡住（前面还有地面）却弹了 %d 次" % [k, dn, str(p0), held])
                    continue
                edge_n += 1
                n_edge += 1
                # 走开再回来（先往回走；回不去就往两边走；都走不开的地方这一条不量）
                var away := false
                for dv in [-d, Vector2(d.y, d.x), Vector2(-d.y, -d.x)]:
                    c.reset_to(p0)
                    tick(2)
                    c.stick = dv
                    tick(60)
                    c.stick = Vector2.ZERO
                    if c.pos.distance_to(p0) > 70.0:
                        away = true
                        break
                var b_away: int = bumps
                if away:
                    c.stick = d
                    tick(int(1.5 / DT))
                    c.stick = Vector2.ZERO
                var again: int = bumps - b_away
                if not away:
                    skipped_rearm += 1
                    again = 1
                if not (first == 1 and held == 1 and again == 1 and shown == str(texts[dn])):
                    bump_bad.append("%s 往%s 在 %s：先弹 %d 次（话「%s」）、顶着不放共 %d 次、走开再回来那一推弹 %d 次" % [k, dn, str(p0), first, shown, held, again])
        cover[k] = [n_edge, n_blk]
        # 点范围外、点家具上
        go_canvas(k)
        var out_p := Vector2.ZERO
        var cw2 := float(c.cfg["size"][0])
        var ch2 := float(c.cfg["size"][1])
        for gy in range(1, 20):
            for gx in range(1, 20):
                var cand := Vector2(cw2 * float(gx) / 20.0, ch2 * float(gy) / 20.0)
                if out_p != Vector2.ZERO or c.in_walk(cand):
                    continue
                var nx := false
                for e in exit_ps:
                    if cand.distance_to(e) < 160.0:
                        nx = true
                if not nx and cand.distance_to(c.SPAWN) > 80.0:
                    out_p = cand
        if out_p != Vector2.ZERO:
            c.reset_to(c.SPAWN)
            tick(3)
            bumps = 0
            c.path.clear()
            c.tap(c.get_viewport().get_canvas_transform() * out_p)
            tick(2)
            c.path.clear()
            if bumps != 1:
                bump_bad.append("%s 点范围外 %s 弹了 %d 次（该 1 次）" % [k, str(out_p), bumps])
    print("    每块量到的 [真走到头, 被挡住] 处数：%s" % str(cover))
    var no_edge: Array = []
    for k in keys:
        if int(cover.get(k, [0, 0])[0]) == 0:
            no_edge.append(k)
    check("每块至少有一处真走到头量过（没量到的块：%s；后厅四周全是门和墙、墙后面是屋里的地，离门 260 像素以外没有真走到头的地方，允许）" % str(no_edge), no_edge.is_empty() or no_edge == ["backhall"])
    check("走到头不再写顶上提示条（%d 次写了）、同一时间只留一个小气泡（%d 次留了不止一个）" % [note_wrote, multi_live], note_wrote == 0 and multi_live == 0)
    for b in bump_bad:
        print("    ", b)
    check("走到头：%d 处弹一句、顶着不重复、走开再回来再弹（%d 处四周走不开没量这条）；%d 处被墙、家具挡住前面还有地不弹（其中 %d 处是湖边南墙外往北顶、算走到头弹了，话是对的）；点范围外弹（%d 处不对）" % [edge_n, skipped_rearm, blocked_n, wall_known, bump_bad.size()], bump_bad.is_empty() and edge_n >= 20)

    print("4 牌子")
    var over_list: Array = []
    var out_list: Array = []
    for k in keys:
        var c = canvas_of(k)
        var cw := float(c.cfg["size"][0])
        var ch := float(c.cfg["size"][1])
        var spots: Dictionary = {"出生": c.SPAWN}
        for pid in c.points:
            if str(c.points[pid]["to"]) != "":
                spots["口 " + pid] = c.points[pid]["pos"]
                spots["落点 " + pid] = c.arrival_at(pid)
        go_canvas(k)
        for lb in c.labels.get_children():
            if not lb is Label:
                continue
            var l := lb as Label
            var home_x: float = float(l.get_meta("home")) if l.has_meta("home") else l.position.x   # 牌子会跟着镜头挪回屏里，量原位（home）
            var r := Rect2(Vector2(home_x, l.position.y), l.size)
            if r.position.x < -2.0 or r.position.y < -2.0 or r.end.x > cw + 2.0 or r.end.y > ch + 2.0:   # 容 2 像素（字体量出来的宽度有零点几的浮动）
                out_list.append("%s「%s」出画布 %s" % [k, l.text, str(r)])
            for sk in spots:
                var sp: Vector2 = spots[sk]
                var body := Rect2(sp.x - 20.0, sp.y - 90.0, 40.0, 90.0)
                var ov := r.intersection(body)
                if ov.size.x > 0.0 and ov.size.y > 0.0:
                    over_list.append("%s %s %s：牌「%s」%s 盖人 %.0f×%.0f" % [k, sk, str(sp), l.text, str(r), ov.size.x, ov.size.y])
    for b in over_list:
        print("    ", b)
    for b in out_list:
        print("    ", b)
    check("十四块、每块牌跟出生点、口、落点上站的人（40×90）不叠（%d 处）" % over_list.size(), over_list.is_empty())
    check("牌子都在画布里（%d 处出去）" % out_list.size(), out_list.is_empty())
    var vis_bad: Array = []
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        for k in keys:
            var c = canvas_of(k)
            go_canvas(k)
            for lb in c.labels.get_children():
                if not (lb is Label) or not ((lb as Label).text.begins_with("去") or (lb as Label).text.begins_with("回")):
                    continue
                var l := lb as Label
                var r0 := Rect2(l.global_position, l.size)
                var best := Vector2.ZERO
                var bd := INF
                for id in c.points:
                    if str(c.points[id]["to"]) == "":
                        continue
                    var dd: float = (c.points[id]["pos"] as Vector2).distance_to(r0.get_center())
                    if dd < bd:
                        bd = dd
                        best = c.points[id]["pos"]
                c.reset_to(best)
                c.cam.reset_smoothing()
                await frames(6)
                var r := Rect2(l.global_position, l.size)
                var cc: Vector2 = c.cam.get_screen_center_position()
                var sv: SubViewport = m.view.get_child(0)
                var vis := Rect2(cc - Vector2(sv.size) / c.cam.zoom.x * 0.5, Vector2(sv.size) / c.cam.zoom.x)
                if not vis.encloses(r):
                    vis_bad.append("%dx%d %s「%s」（人站 %s，屏 %s，牌 %s）" % [sz.x, sz.y, k, l.text, str(best), str(vis), str(r)])
    get_root().size = Vector2i(540, 960)
    for b in vis_bad:
        print("    ", b)
    check("手机 540×960 和长屏 585×1266 下，人站在口上，对应「去…」牌整块在屏里（%d 处不对）" % vis_bad.size(), vis_bad.is_empty())
    # 宴会厅的门牌：跟进厅落点不叠
    var h = m.hall
    var hall_spots := {"南门口进厅": h.SPAWN, "西侧门里": h.side_arrive, "东侧门里": h.exits[0]["arrive"]}
    var hall_over: Array = []
    for hs in h.room_signs:
        var lbl = (hs as Node2D).get_child(0)
        if not lbl is Label:
            continue
        var r := Rect2((hs as Node2D).position + (lbl as Control).position, (lbl as Control).size)
        for sk in hall_spots:
            var sp: Vector2 = hall_spots[sk]
            var body := Rect2(sp.x - 20.0, sp.y - 90.0, 40.0, 90.0)
            if r.intersects(body):
                hall_over.append("宴会厅牌「%s」%s 盖 %s %s" % [(lbl as Label).text, str(r), sk, str(sp)])
    for b in hall_over:
        print("    ", b)
    check("宴会厅门牌（后厅、后花园…）跟进厅落点站的人叠了 %d 处（第 65 版是 2 处：西门「后厅」牌、东门「后花园」牌盖住刚进来的人，第 66 版 02 把牌抬高后清零，从此要求 0）" % hall_over.size(), hall_over.is_empty())

    # 停车场：车跟车、车跟洗手间、杂物处小屋，画出来的范围（顶面 + 前脸：y0 - 高 到 y1）两两不叠（第 65 版小屋压在最南一排 3 辆车上，第 66 版 02 把停车场往南加长）
    var pk_items: Array = []
    for it in m.parking.cfg["items"]:
        if it.has("rect") and it.has("h") and (str(it["id"]).begins_with("car") or str(it["id"]).begins_with("house")):
            pk_items.append(it)
    var pk_over: Array = []
    for i in pk_items.size():
        for j in range(i + 1, pk_items.size()):
            var ra: Array = pk_items[i]["rect"]
            var rb: Array = pk_items[j]["rect"]
            var ea := Rect2(float(ra[0]), float(ra[1]) - float(pk_items[i]["h"]), float(ra[2]) - float(ra[0]), float(ra[3]) - float(ra[1]) + float(pk_items[i]["h"]))
            var eb := Rect2(float(rb[0]), float(rb[1]) - float(pk_items[j]["h"]), float(rb[2]) - float(rb[0]), float(rb[3]) - float(rb[1]) + float(pk_items[j]["h"]))
            if ea.intersects(eb):
                pk_over.append("%s × %s" % [pk_items[i]["id"], pk_items[j]["id"]])
    for b in pk_over:
        print("    停车场叠：", b)
    check("停车场 %d 件（车 + 小屋）画出来的范围两两不叠（%d 对叠）" % [pk_items.size(), pk_over.size()], pk_over.is_empty() and pk_items.size() >= 12)

    # 「休息区 2」改叫「休息厅 2」（阿鱼 10/4）：除迎宾院自己那块「休息区」（院子里的茶桌），玩家看得见的牌、标题、话里不许再出现「休息区」
    var old_name: Array = []
    for k in keys:
        if k == "court":
            continue
        var c = canvas_of(k)
        for hit in find_text(c.cfg, "休息区"):
            old_name.append("%s 布局里 %s" % [k, hit])   # 标题、牌子、flat 里的字，note 说明不算
        for lb in c.labels.get_children():
            if lb is Label and (lb as Label).text.find("休息区") >= 0:
                old_name.append("%s 牌「%s」" % [k, (lb as Label).text])
    for jp in ["res://assets/areas/lines.json", "res://assets/plaza/lines.json"]:
        var jd = JSON.parse_string(FileAccess.get_file_as_string(jp))
        if jd is Dictionary:
            for key in jd:
                if jd[key] is Dictionary and str((jd[key] as Dictionary).get("text", "")).find("休息区") >= 0:
                    old_name.append("%s 的 %s：%s" % [jp, key, str(jd[key]["text"])])   # 只看玩家看得见的 text，note 说明不算
    for b in old_name:
        print("    ", b)
    check("「休息区 2」全改成「休息厅 2」：非迎宾院的标题、牌子、话里没有「休息区」残留（%d 处）" % old_name.size(), old_name.is_empty())

    print("5 老的落点常量（main.gd 里留着、没有对口的口时才用的兜底）")
    var olds := {
        "COURT_FROM_HALL": ["court", m.COURT_FROM_HALL], "COURT_FROM_PLAZA": ["court", m.COURT_FROM_PLAZA], "COURT_FROM_LAKE": ["court", m.COURT_FROM_LAKE],
        "BACKHALL_FROM_HALL": ["backhall", m.BACKHALL_FROM_HALL], "BACKHALL_FROM_LAWN": ["backhall", m.BACKHALL_FROM_LAWN], "BACKHALL_FROM_PLAZA": ["backhall", m.BACKHALL_FROM_PLAZA],
        "LAWN_FROM_PLAZA": ["lawn", m.LAWN_FROM_PLAZA], "LAWN_FROM_BACKHALL": ["lawn", m.LAWN_FROM_BACKHALL], "LAWN_FROM_ORCHARD": ["lawn", m.LAWN_FROM_ORCHARD],
        "LAKE_FROM_COURT": ["lake", m.LAKE_FROM_COURT], "ORCHARD_FROM_LAWN": ["orchard", m.ORCHARD_FROM_LAWN],
        "plaza.FROM_COURT": ["plaza", m.plaza.FROM_COURT], "plaza.FROM_LAWN": ["plaza", m.plaza.FROM_LAWN], "plaza.FROM_BACKHALL": ["plaza", m.plaza.FROM_BACKHALL],
        "parking.FROM_COURT": ["parking", m.parking.FROM_COURT], "parking.FROM_LAKE": ["parking", m.parking.FROM_LAKE], "lake.FROM_ORCHARD": ["lake", m.lake.FROM_ORCHARD],
    }
    var old_bad: Array = []
    for k in olds:
        var cn: String = olds[k][0]
        var pos: Vector2 = olds[k][1]
        if pos == Vector2.ZERO:
            continue   # 没设（兜底不会用）
        var c = canvas_of(cn)
        if not c._free(pos):
            old_bad.append("%s %s 在 %s 上站不了" % [k, str(pos), cn])
    var hp: Vector2 = m.HALL_FROM_BACKHALL
    if not m.hall._free(hp):
        old_bad.append("HALL_FROM_BACKHALL %s 在宴会厅里站不了" % str(hp))
    for b in old_bad:
        print("    ", b)
    print("    兜底落点站不了的有 %d 个（这些只有「对面没有通回来的口」时才会用到，现在 52 条连法都有对口，走不到）" % old_bad.size())

    DirAccess.remove_absolute("user://test_extra_court.json")
    DirAccess.remove_absolute("user://test_extra_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
