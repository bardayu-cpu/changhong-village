extends SceneTree
## 验收：第 68 版（07 10/4，01 H 派）开车路线、下车提示、路牌箭头。无界面跑整个 main.gd。
##   1 前门正对喷泉：前门北口、广场南边去前门的口、喷泉中心三点 x 一样；广场东边下面的口去停车场、停车场西边上面的口去广场
##   2 停车场放大：画布比原来宽（> 1024）、车位从 12 个变 24 个；北墙两道门（去迎宾院、去后花园）
##   3 下车提示：新号开完车下车 → 顶部说「park_sign」那句、金箭头指迎宾院那道门；走进迎宾院、再走回停车场（没签到）箭头照样指；
##     签完到再回停车场：箭头收了；签过到的再开一趟：下车不说那句、箭头不出
##   4 迎宾院大门出去到停车场（站在去迎宾院那道门里边）；停车场那道门进去到迎宾院（站在大门里边），不弹回去
##   5 路牌箭头：十四块所有「去…」「回…」牌都加了箭头；往上、往左放字前，往右、往下放字后；方向跟牌子对的那个口在画布哪条边一致；牌子都在画布里
## 用法：Godot --headless --path . --script res://tools/test_drive68.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_drive68_court.json"
var m
var started := false
var ok := true

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

func set_save(d: Dictionary) -> void:
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify(d))
    f.close()
    m.court_save.local_path = SAVE
    m.court_save.load_local()

func frames(n: int) -> void:
    for i in n:
        await process_frame

## 开一趟车（fast 模式真开），等停好下车
func drive() -> void:
    m.drive_in_fast = true
    m._start_play()
    for i in 6000:
        await process_frame
        if not m.driving and m.state == "parking" and not m.switching:
            break
    await frames(20)
    m.drive_in_fast = false

func walk_to(p: Vector2) -> void:
    m.cv.walking_enabled = true
    m.cv.go_to(p)
    for i in 1200:
        await process_frame
        if m.switching:
            continue
        if m.cv.path.is_empty():
            break
    for i in 40:
        await process_frame
        if not m.switching:
            break
    await frames(10)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.games_save.local_path = "user://test_drive68_games.json"
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    var keys: Array = ["backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        m.ensure_canvas(k)
    var fg = m._canvas_by("frontgate")
    var pz = m.plaza
    var pk = m.parking

    print("1 前门正对喷泉")
    var fx := 0.0
    for it in pz.cfg["items"]:
        if str(it.get("id", "")) == "fountain_basin":
            fx = float(it["x"])
    check("前门北口 x %.0f、广场南口（去前门）x %.0f、喷泉 x %.0f 在一条竖线上" % [fg.points["to_plaza"]["pos"].x, pz.points["to_frontgate"]["pos"].x, fx],
        fg.points["to_plaza"]["pos"].x == fx and pz.points["to_frontgate"]["pos"].x == fx and fg.edge_of(fg.points["to_plaza"]["pos"]) == "up" and pz.edge_of(pz.points["to_frontgate"]["pos"]) == "down")
    check("广场东边下面去停车场（%s，在去迎宾院那个口下面）、停车场西边上面去广场（%s，在去前门那个口上面）" % [str(pz.points.get("to_parking", {}).get("pos")), str(pk.points.get("to_plaza", {}).get("pos"))],
        pz.points.has("to_parking") and pz.edge_of(pz.points["to_parking"]["pos"]) == "right" and pk.points.has("to_plaza") and pk.edge_of(pk.points["to_plaza"]["pos"]) == "left"
        and pz.points["to_parking"]["pos"].y > pz.points["to_court"]["pos"].y and pk.points["to_plaza"]["pos"].y < pk.points["to_frontgate"]["pos"].y)

    print("2 停车场放大")
    var stalls := 0
    var cars := 0
    for it in pk.cfg["items"]:
        if str(it.get("id", "")).begins_with("car_"):
            cars += 1
    for f in pk.cfg["flat"]:
        var r: Array = f.get("rect", [])
        if r.size() == 4 and str(f.get("color", "")) == "#e8e4d8" and float(r[2]) - float(r[0]) <= 4.0:
            stalls += 1
    check("停车场画布 %s（原来 1024 宽）、车位竖线 %d 条（两片各三排五条 = 30，原来 15）、车 %d 辆" % [str(pk.cfg["size"]), stalls, cars],
        float(pk.cfg["size"][0]) > 1024.0 and stalls == 30 and cars >= 14)
    check("停车场北墙两道门：去迎宾院、去后花园都朝上", pk.edge_of(pk.points["to_court"]["pos"]) == "up" and pk.edge_of(pk.points["to_garden"]["pos"]) == "up"
        and pk.points["to_court"]["pos"].x < pk.points["to_garden"]["pos"].x)

    print("3 下车提示")
    set_save({})
    await drive()
    var line: String = m.CourtCopy.text("park_sign")
    var said: String = m.dialog_label.text if m.get("dialog_label") != null else ""
    var spoke: bool = m.dialog.visible and (line in str(m.dialog.find_child("*", true, false)) or _dialog_has(line))
    check("新号下车：顶部说「%s」（%s）" % [line, spoke], line != "" and not line.begins_with("【") and spoke)
    pk._process(DT)
    var arr: Polygon2D = pk.guide_arrow
    var tgt: Vector2 = pk.guide_target()
    check("金箭头出着、指迎宾院那道门 %s（箭头朝 %.0f°，门在 %.0f°）" % [str(tgt), rad_to_deg(arr.rotation), rad_to_deg((tgt - (pk.pos - Vector2(0, 46))).angle())],
        arr.visible and tgt == pk.points["to_court"]["pos"] and absf(angle_difference(arr.rotation, (tgt - (pk.pos - Vector2(0, 46))).angle())) < 0.05)
    m.dialog.visible = false
    await walk_to(pk.points["to_court"]["pos"])
    check("走进那道门到了迎宾院（%s），站在大门里边 %s" % [m.state, str(m.court.pos)], m.state == "court" and m.court.pos.distance_to(m.court.SPAWN) < 2.0)
    await walk_to(m.court.SPAWN + Vector2(0, -120))
    await walk_to(m.court.spot_pos("gate"))
    var land: Vector2 = pk.arrival_from("court")
    check("迎宾院大门出去到了停车场（%s），站在去迎宾院那道门里边 %s（该站 %s）" % [m.state, str(pk.pos), str(land)], m.state == "parking" and pk.pos.distance_to(land) < 2.0)
    await frames(60)
    check("站在门里边不弹回迎宾院", m.state == "parking")
    # 刚进门离那道门不到 110 像素，箭头照设计不出（离目标近就不指）；走开一段再看
    await walk_to(pk.SPAWN)
    pk._process(DT)
    check("没签到走回停车场：走开以后箭头照样指迎宾院（gate_hint %s）" % pk.gate_hint, pk.gate_hint and pk.guide_arrow.visible and pk.guide_target() == pk.points["to_court"]["pos"])
    m.court_save.signed_in = true
    await walk_to(pk.points["to_court"]["pos"])
    await walk_to(m.court.SPAWN + Vector2(0, -120))
    await walk_to(m.court.spot_pos("gate"))
    pk._process(DT)
    check("签完到再回停车场：箭头收了（%s）" % pk.guide_arrow.visible, m.state == "parking" and not pk.guide_arrow.visible)
    set_save({"welcomed": true, "signed_in": true, "court_seen": true})
    m.dialog.visible = false
    await drive()
    pk._process(DT)
    check("签过到的再开一趟：下车不说那句、箭头不出", not _dialog_has(line) and not pk.guide_arrow.visible)

    print("5 路牌箭头")
    var bad: Array = []
    var n := 0
    for k in ["court"] + keys:
        var c = m.court if k == "court" else m._canvas_by(k)
        var sz: Array = c.cfg["size"]
        for l in c.labels.get_children():
            if not l is Label or not l.has_meta("sign"):
                continue
            n += 1
            var raw := str(l.get_meta("sign"))
            var t := (l as Label).text
            var center: Vector2 = (l as Label).position + (l as Label).size * 0.5
            if l.has_meta("home"):
                center.x = float(l.get_meta("home")) + (l as Label).size.x * 0.5   # 离开屏幕时游戏会把牌子临时往屏幕里收，按原位置核
            var target: Vector2 = c.sign_target(raw, center)
            var want: String = c.edge_of(target) if target != Vector2.ZERO else ""
            var a: String = {"up": "↑", "down": "↓", "left": "←", "right": "→"}.get(want, "?")
            var good: bool = want != "" and (t == a + " " + raw if want in ["up", "left"] else t == raw + " " + a)
            var r := Rect2((l as Label).position, (l as Label).size)
            if not Rect2(0, 0, float(sz[0]), float(sz[1])).encloses(r):
                good = false
            # 照箭头直走能到口（第 68 版小修，04：「去小卖部 ↓」往下走是绿篱）：口在牌子的箭头那边（往前 > 0），横着偏不超过 60 像素（口宽 72 上下）
            var dv: Vector2 = {"up": Vector2(0, -1), "down": Vector2(0, 1), "left": Vector2(-1, 0), "right": Vector2(1, 0)}.get(want, Vector2.ZERO)
            var dd: Vector2 = target - center
            var along: float = dd.dot(dv)
            var lat: float = absf(dd.x * dv.y - dd.y * dv.x)
            if along <= 0.0 or lat > 60.0:
                good = false
                t += "（往前 %.0f、横偏 %.0f）" % [along, lat]
            if not good:
                bad.append("%s「%s」（口 %s 朝 %s）" % [k, t, str(target), want])
    # 同一块里两块牌不叠（第 69 版小修，04：广场南边几块牌挤在一起）——按牌子的原位置量（离开屏幕时游戏会临时往屏幕里收）
    for k in ["court"] + keys:
        var c = m.court if k == "court" else m._canvas_by(k)
        var rs: Array = []
        for l in c.labels.get_children():
            if l is Label and l.has_meta("dir"):
                var px: float = float(l.get_meta("home")) if l.has_meta("home") else (l as Label).position.x
                rs.append([(l as Label).text, Rect2(Vector2(px, (l as Label).position.y), (l as Label).size)])
        for i in rs.size():
            for j in range(i + 1, rs.size()):
                if (rs[i][1] as Rect2).intersects(rs[j][1]):
                    bad.append("%s「%s」跟「%s」叠了" % [k, rs[i][0], rs[j][0]])
    for b in bad:
        print("    ", b)
    check("十四块 %d 块「去…」「回…」牌都加了箭头、方向跟口一致、位置对（前/后）、都在画布里、照箭头直走能到口（横偏 ≤ 60）、同一块里不互相叠（不对 %d 块）" % [n, bad.size()], n >= 50 and bad.is_empty())

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_drive68_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

func _dialog_has(line: String) -> bool:
    if not m.dialog.visible:
        return false
    for ch in m.dialog.find_children("*", "Label", true, false):
        if line in (ch as Label).text:
            return true
    return false
