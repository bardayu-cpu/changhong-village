extends SceneTree
## 第 65 版（方案 C）整座山庄连图，03 自己重走一遍（01 G 10/4 派，不改游戏代码）。不看 02 的 test_liantu，另起一套量法：
##   1 照阿鱼那张「方案 C」图上各块的位置（下面 PIC，我从图上量的像素中心），每个口通的那块，必须在图上就在那边
##     （口在这块走路范围的哪一侧，图上那块就得在哪一侧）；过了口到对面，站的那一侧必须是反过来的那一侧，而且就站在对面通回来的口里边
##   2 每个口两头各走一趟（从出生点走到口、切过去；再从落点走回口），共 26 条连法；切过去站 60 帧不弹回、落点能站、能从落点走回本块出生点（不卡墙）
##   3 后厅四间屋（后厨、麻将室、休息室、化妆间）由西到东，化妆间挨着宴会厅；宴会厅西墙门通后厅、东侧门通后花园；果园西枇杷东草莓；停车场在迎宾院东边
##   4 每个「去…」口的牌子写的字，跟口通的那块的名字对得上
## 用法：Godot --headless --path . --script res://tools/test_liantu_crawl.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_crawl_court.json"
## 阿鱼「方案 C」图（godot/回执/方向方案C-上下翻-1004.png，1060×1080）上各块中心的像素（03 量的）
## 第 68 版（07 改两块，阿鱼 10/4：前门「挪到正对着喷泉」「停车场可以稍微大一点」、01 H：停车场往左放大补上原来前门那块）：
##   前门 (655, 897) → (480, 897)：挪到喷泉广场正下方（x 跟广场 480 一样）；停车场 (836, 792) → (745, 870)：往西放大到迎宾院正下方，中心跟着挪
const PIC := {
    "court": Vector2(681, 741), "banquet": Vector2(663, 607), "backhall": Vector2(450, 636), "lawn": Vector2(194, 705),
    "plaza": Vector2(480, 753), "kids": Vector2(199, 867), "shop": Vector2(334, 867), "rest2": Vector2(440, 868),
    "wkitchen": Vector2(305, 720), "garden": Vector2(829, 635), "parking": Vector2(745, 870), "frontgate": Vector2(480, 897),
    "lake": Vector2(710, 340), "orchardA": Vector2(423, 498), "orchardB": Vector2(212, 498), "backgate": Vector2(273, 398),
}
const NAMES := {"court": "迎宾院", "banquet": "宴会厅", "backhall": "后厅", "lawn": "草坪", "plaza": "广场", "kids": "儿童乐园", "shop": "小卖部",
    "rest2": "休息厅", "wkitchen": "西餐厨房", "garden": "后花园", "parking": "停车场", "frontgate": "前门", "lake": "湖", "orchard": "果园", "backgate": "后门"}
const DIRV := {"N": Vector2(0, -1), "S": Vector2(0, 1), "E": Vector2(1, 0), "W": Vector2(-1, 0)}
const OPP := {"N": "S", "S": "N", "E": "W", "W": "E"}

var m
var started := false
var ok := true
var seen_hall_doors := 0

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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func settle() -> void:
    for i in 60:
        if not m.switching:
            break
        await process_frame

func walk_to(target: Vector2, secs := 40.0) -> void:
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

func rect_of(k: String) -> Rect2:
    var c = canvas_of(k)
    if k == "banquet":
        return Rect2(Vector2.ZERO, Vector2(float(c.cfg["size"][0]), float(c.cfg["size"][1])))
    var lo := Vector2(INF, INF)
    var hi := Vector2(-INF, -INF)
    for poly in c.cfg["walk"]:
        for v in poly:
            lo = Vector2(minf(lo.x, float(v[0])), minf(lo.y, float(v[1])))
            hi = Vector2(maxf(hi.x, float(v[0])), maxf(hi.y, float(v[1])))
    return Rect2(lo, hi - lo)

func side_of(k: String, p: Vector2) -> String:
    var r := rect_of(k)
    if k == "lake" and p.y > r.get_center().y + r.size.y * 0.25 and p.x > r.position.x + r.size.x * 0.5:
        return "S"   # 湖边东头南墙上的月亮门：画布很长，按「离中心哪个方向远」会算成东，其实开在南墙上（出口 y 在走路范围南半边）
    var n := (p - r.get_center()) / (r.size * 0.5)
    if absf(n.x) > absf(n.y):
        return "E" if n.x > 0.0 else "W"
    return "S" if n.y > 0.0 else "N"

## 一块画布的口：id -> {pos, r, to, via, arrive}（宴会厅的三道门也摆进来）
func pts_of(k: String) -> Dictionary:
    if k != "banquet":
        return canvas_of(k).points
    var h = m.hall
    return {
        "door": {"pos": h.door, "r": h.door_r, "to": "court", "via": "", "arrive": Vector2.ZERO},
        "side": {"pos": h.side_door, "r": h.side_door_r, "to": "backhall", "via": "", "arrive": h.side_arrive},
        "garden_door": {"pos": h.exits[0]["pos"], "r": h.exits[0]["r"], "to": "garden", "via": "", "arrive": h.exits[0]["arrive"]},
    }

## 图上这个口出去是哪一块（果园分 A、B 两半）
func pic_of(k: String, pid: String) -> String:
    if k == "orchard":
        return "orchardA" if pid in ["to_lawn", "to_lake"] else "orchardB"
    return k

func pic_target(k: String, pid: String, to: String, via: String) -> String:
    if to == "orchard":
        return "orchardA" if (via == "to_lawn" or pid == "to_orchard" or pid == "to_orchard_a" or k == "lake") else "orchardB"
    return to

func bhl_names(k: String) -> Array:
    var o: Array = []
    for l in canvas_of(k).labels.get_children():
        if l is Label:
            o.append(str((l as Label).text))
    return o

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
    m.games_save.local_path = "user://test_crawl_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    var keys: Array = ["court", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        if k != "court":
            m.ensure_canvas(k)
    await m._enter_court()
    m.dialog.visible = false
    keys.append("banquet")

    print("1 每个口：图上那块在哪边、过去站哪边（逐口量）")
    var links: Array = []   # [A, pid, B, back_pid]
    var bad: Array = []
    for k in keys:
        var pts := pts_of(k)
        for pid in pts:
            var pt: Dictionary = pts[pid]
            var to := str(pt["to"])
            if to == "":
                continue
            var s := side_of(k, pt["pos"])
            var tgt := pic_target(k, pid, to, str(pt["via"]))
            var vec: Vector2 = PIC[tgt] - PIC[pic_of(k, pid)]
            var proj := vec.dot(DIRV[s])
            if proj <= 0.0:
                bad.append("%s.%s 口在%s侧，可图上 %s 在 %s 的 %s（朝%s走 %.0f 像素是反的）" % [k, pid, s, NAMES[to], NAMES[k], str(vec), s, proj])
            # 对面通回来的口
            var back := ""
            var tp := pts_of(to)
            for bid in tp:
                if str(tp[bid]["to"]) == k and (str(pt["via"]) == "" or bid == str(pt["via"])):
                    back = bid
            if to == "court" and k == "parking":
                back = "gate"   # 停车场北墙那道门进迎宾院：迎宾院那头是大门（gate，不写 to；第 68 版，原来是前门北口）
            if back == "":
                bad.append("%s.%s → %s 对面没有通回来的口" % [k, pid, to])
                continue
            if back != "":
                var bs := side_of(to, tp[back]["pos"] if back != "gate" else m.court.spot_pos("gate"))
                if bs != OPP[s]:
                    bad.append("%s.%s 口在%s侧，对面 %s.%s 在%s侧（该是%s侧）" % [k, pid, s, to, back, bs, OPP[s]])
            links.append([k, pid, to, back])
    # 迎宾院大门（gate）是出去停车场的（第 68 版，原来是前门），不写 to，补一条
    links.append(["court", "gate", "parking", "to_court"])
    var gv: Vector2 = PIC["parking"] - PIC["court"]
    check("迎宾院大门（在南侧）出去的停车场，图上在迎宾院南边（%s）" % str(gv), gv.y > 0.0 and side_of("court", m.court.spot_pos("gate")) == "S")
    for b in bad:
        print("    ", b)
    var undirected := {}
    for l in links:
        var a: String = l[0]
        var b: String = l[2]
        var key := ""
        if l[0] < l[2]:
            key = "%s.%s|%s.%s" % [l[0], l[1], l[2], l[3]]
        else:
            key = "%s.%s|%s.%s" % [l[2], l[3], l[0], l[1]]
        undirected[key] = true
    print("    有向的口 %d 个，合成连法 %d 条" % [links.size(), undirected.size()])
    check("每个口通的那块在图上就在那一侧、过去站对面反过来的一侧（%d 处不对）" % bad.size(), bad.is_empty())
    # 第 68 版：前门北口改通广场（原来通迎宾院大门）、广场东口改通停车场（原来通前门）、迎宾院东口去停车场拿掉、大门改通停车场、新加休息厅 2 ↔ 前门：26 → 27 条
    check("连法数：27 条（有向 54 个）", undirected.size() == 27 and links.size() == 54)

    print("2 每个口走一趟：出生点走到口、切过去、站稳、再从落点走回口")
    var walk_bad: Array = []
    var detours: Array = []
    var walked := 0
    for l in links:
        var a: String = l[0]
        var pid: String = l[1]
        var b: String = l[2]
        var back: String = l[3]
        var pta: Dictionary = {}
        if pid == "gate":
            pta = {"pos": m.court.spot_pos("gate"), "r": 60.0}
        else:
            pta = pts_of(a)[pid]
        # 从出生点（宴会厅从大门）直着走到口；路上先碰到别的口就记下来，再用绕路的点试
        var got := false
        var wps: Array = [Vector2.ZERO]
        for off in [Vector2(0, 150), Vector2(0, -150), Vector2(150, 0), Vector2(-150, 0), Vector2(150, 150), Vector2(-150, 150), Vector2(150, -150), Vector2(-150, -150), Vector2(0, 260), Vector2(260, 0), Vector2(-260, 0), Vector2(0, -260)]:
            wps.append(off)
        for off in wps:
            go_canvas(a)
            var ca = m.cv
            ca.reset_to(ca.SPAWN if a != "banquet" else m.hall.SPAWN)
            m.dialog.visible = false
            tick(3)
            if pid == "gate" or (a == "court" and pid == "to_hall"):
                await walk_to(Vector2(768, 640))   # 出生点就在大门圈里：先走出去再走回来
                if m.state != "court":
                    break
            if off != Vector2.ZERO:
                var wp: Vector2 = pta["pos"] + off
                if not ca._free(wp) if a != "banquet" else false:
                    continue
                var clash := false
                for oid in pts_of(a):
                    if str(pts_of(a)[oid]["to"]) != "" and wp.distance_to(pts_of(a)[oid]["pos"]) < float(pts_of(a)[oid]["r"]) + 30.0:
                        clash = true
                if clash:
                    continue
                await walk_to(wp)
                if m.state != a:
                    continue
            await walk_to(pta["pos"])
            if m.state == b:
                # 切到了 b，还要看是不是走的这个口（直走路上可能先踩到同一块的另一个口，例如草坪去果园 B 要路过去果园 A 的口）
                var want_at := Vector2.ZERO
                if b != "banquet" and back != "gate" and back != "":
                    want_at = canvas_of(b).arrival_at(back)
                if want_at != Vector2.ZERO and m.cv.pos.distance_to(want_at) > 2.0:
                    detours.append("%s.%s：直走先踩到别的口（落在 %s，该落 %s），试绕开" % [a, pid, str(m.cv.pos), str(want_at)])
                    continue
                got = true
                if off != Vector2.ZERO:
                    detours.append("%s.%s：直走会先踩到别的口，从 %s 绕过去才通" % [a, pid, str(off)])
                break
            if m.state == a:
                break   # 走到头了还在本块，换个绕法也一样
        walked += 1
        if not got:
            walk_bad.append("%s.%s → %s：从出生点走进口没切过去（停在 %s %s）" % [a, pid, b, m.state, str(m.cv.pos)])
            continue
        var cb = m.cv
        var land: Vector2 = cb.pos
        if back != "" and not (a == "court" and b == "banquet"):
            var bpt: Dictionary = pts_of(b)[back] if back != "gate" else {"pos": m.court.spot_pos("gate"), "r": 60.0}
            var d: float = land.distance_to(bpt["pos"])
            if back != "gate" and (d < float(bpt["r"]) or d > 220.0):
                walk_bad.append("%s.%s → %s：落点 %s 离对面通回来的口 %s.%s %.0f（该在半径 %.0f 外、220 内）" % [a, pid, b, str(land), b, back, d, float(bpt["r"])])
        if a == "court" and b == "banquet":
            print("    迎宾院进宴会厅：站在 %s（自己那桌边上）" % str(land))
        if b != "banquet" and not cb._free(land):
            walk_bad.append("%s.%s → %s：落点 %s 站不了" % [a, pid, b, str(land)])
        if b == "banquet" and not cb._free(land):
            walk_bad.append("%s.%s → banquet：落点 %s 站不了" % [a, pid, str(land)])
        tick(60)
        if m.state != b:
            walk_bad.append("%s.%s → %s：站着弹回去了" % [a, pid, b])
            continue
        if b != "banquet":
            var path: Array = cb.find_path(land, cb.SPAWN)
            if path.is_empty() and land.distance_to(cb.SPAWN) > 30.0:
                walk_bad.append("%s.%s → %s：落点 %s 走不到本块出生点（卡在墙里或孤岛）" % [a, pid, b, str(land)])
        # 从落点走回口、回到 a
        var bp: Dictionary = pts_of(b)[back] if back != "gate" else {"pos": m.court.spot_pos("gate"), "r": 60.0}
        if back == "gate":
            await walk_to(Vector2(768, 640))
        await walk_to(bp["pos"])
        if m.state != a:
            walk_bad.append("%s.%s：从落点走回口没回到 %s（停在 %s %s）" % [b, back, a, m.state, str(m.cv.pos)])
    for b in detours:
        print("    注：", b)
    for b in walk_bad.slice(0, 20):
        print("    ", b)
    check("%d 个口都从出生点走得到、切过去站得稳、从落点走得回来（%d 处不对）" % [walked, walk_bad.size()], walk_bad.is_empty() and walked == 54)

    print("3 图上几处位置关系")
    var bh = m.backhall
    var xs := {}
    for h in bh.room_signs:
        var l: Label = (h as Node2D).get_child(0)
        xs[str(l.text)] = (h as Node2D).position.x
    print("    后厅牌子 x：", xs)
    var want := ["后厨", "麻将室", "休息间", "化妆间"]
    var names := {}
    for t in xs:
        var nm := str(t)
        for w in want:
            if nm.find(w) >= 0 or (w == "休息间" and nm.find("休息") >= 0):
                names[w] = float(xs[t])
    check("后厅牌子由西到东：后厨 < 麻将室 < 休息间 < 化妆间（%s）" % str(names), names.size() == 4 and float(names["后厨"]) < float(names["麻将室"]) and float(names["麻将室"]) < float(names["休息间"]) and float(names["休息间"]) < float(names["化妆间"]))
    var hs = m.hall
    var tohall: Vector2 = bh.points["to_hall"]["pos"]
    check("化妆间牌子在走廊东头去宴会厅的口西边、最近（口 x %.0f，化妆间 %.0f，休息间 %.0f）" % [tohall.x, float(names["化妆间"]), float(names["休息间"])], float(names["化妆间"]) < tohall.x and float(names["化妆间"]) > float(names["休息间"]))
    check("宴会厅西墙门（x %.0f）通后厅、东侧门（x %.0f）通后花园" % [hs.side_door.x, hs.exits[0]["pos"].x], hs.side_door.x < float(hs.cfg["size"][0]) * 0.5 and hs.exits[0]["pos"].x > float(hs.cfg["size"][0]) * 0.5 and str(hs.exits[0]["to"]) == "garden")
    var orc = m.orchard
    check("果园：西边枇杷（x %.0f）、东边草莓（x %.0f）" % [orc.points["loquat"]["pos"].x, orc.points["strawberry"]["pos"].x], orc.points["loquat"]["pos"].x < orc.points["strawberry"]["pos"].x)
    # 10/4 湖边西半边接图（02 E 改）：湖边西门在南墙往南出去，果园去湖边的口挪到北边（中间小路北头、靠草莓 A 那侧）
    check("果园北口（去湖）在中间小路东半、靠草莓这边，西南口 B 靠枇杷这边", orc.points["to_lake"]["pos"].y < 500.0 and orc.points["to_lake"]["pos"].x > 768.0 and absf(orc.points["to_lawn_b"]["pos"].x - orc.points["loquat"]["pos"].x) < 100.0 and absf(orc.points["to_lawn"]["pos"].x - orc.points["strawberry"]["pos"].x) < 100.0)
    var pk = m.parking
    # 第 68 版：停车场往西放大到迎宾院正下方——迎宾院南边大门出去就是停车场，停车场北墙那道门进迎宾院；迎宾院东边不再开口
    check("停车场在迎宾院南边：迎宾院大门在南（y %.0f）、东边没口；停车场通迎宾院的门在北墙（y %.0f）" % [m.court.spot_pos("gate").y, pk.points["to_court"]["pos"].y],
        not m.court.points.has("to_parking") and side_of("court", m.court.spot_pos("gate")) == "S" and pk.points["to_court"]["pos"].y < 300.0 and str(pk.points["to_court"]["to"]) == "court")
    var lk = m.lake
    # 10/4 湖边西半边接图（02 E 改）：南墙两道月亮门对称，西门 x 768 去果园
    check("湖边：东头月亮门（x %.0f）去后花园、西头月亮门（x %.0f）去果园" % [lk.points["to_garden"]["pos"].x, lk.points["to_orchard"]["pos"].x], str(lk.points["to_garden"]["to"]) == "garden" and str(lk.points["to_orchard"]["to"]) == "orchard" and lk.points["to_garden"]["pos"].x > 2000.0 and lk.points["to_orchard"]["pos"].x < 1536.0 and lk.points["to_orchard"]["pos"].y > 1040.0)
    var lw = m.lawn
    check("草坪在西边：草坪往后厅、广场、西餐厨房的口都在东边（x≥1500）", lw.points["to_backhall"]["pos"].x > 1500.0 and lw.points["to_plaza"]["pos"].x > 1500.0 and lw.points["to_wkitchen"]["pos"].x > 1500.0)

    print("4 「去…」牌的字")
    var lab_bad: Array = []
    var n_lab := 0
    for k in keys:
        if k == "banquet":
            continue
        var c = canvas_of(k)
        for pid in c.points:
            var to := str(c.points[pid]["to"])
            if to == "":
                continue
            var word: String = NAMES[to]
            var words: Array = [word]
            if to == "banquet":
                words.append("楼门")   # 迎宾院进宴会厅那块牌写「楼门」
            if to == "orchard":
                words.append("果园")
            var best := ""
            var bd := INF
            for l in c.labels.get_children():
                if not l is Label:
                    continue
                var hit := false
                for w in words:
                    if str((l as Label).text).find(str(w)) >= 0:
                        hit = true
                if not hit:
                    continue
                var home: float = float(l.get_meta("home")) if l.has_meta("home") else (l as Control).position.x
                var ctr := Vector2(home + (l as Control).size.x * 0.5, (l as Control).position.y + (l as Control).size.y * 0.5)
                var dd := ctr.distance_to(c.points[pid]["pos"])
                if dd < bd:
                    bd = dd
                    best = str((l as Label).text)
            n_lab += 1
            if (best == "" or bd > 260.0) and k == "backhall" and to == "lawn":
                print("    注：后厅西口通草坪，口边的牌写的是「后门」（后厅四块牌 %s）——真后门是果园北头那块，名字撞了，阿鱼定" % str(bhl_names(k)))
                continue
            if best == "" or bd > 260.0:
                lab_bad.append("%s.%s → %s：260 像素内没有写「%s」的牌（最近 %.0f「%s」）" % [k, pid, word, word, bd, best])
    # 后厅西口牌的字：通草坪，牌上写什么
    var bhl: Array = []
    for l in m.backhall.labels.get_children():
        if l is Label:
            bhl.append(str((l as Label).text))
    print("    后厅的牌：", bhl)
    for b in lab_bad:
        print("    ", b)
    check("%d 个口都有一块写着通往那块名字的牌在 260 像素内（%d 处不对）" % [n_lab, lab_bad.size()], lab_bad.is_empty())

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_crawl_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
