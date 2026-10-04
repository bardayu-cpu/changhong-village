extends SceneTree
## 停车场和大门（01 F 10/3 派；玩家说明 docs/停车场和大门-玩家说明-v0.1.md 第 1、2、3、6 节）：
## 1 摆法：四辆点名的车（紫色宝马双门 240、蓝色 BRZ、白色 911、黑色哈弗 H6）都在、照真车尺寸；车不挡去大门的路；湖不能走
## 2 开头：没进过迎宾院的选完形象从自己车旁边出生，金箭头指大门；走进门洞到迎宾院大门里边，说「到啦～」；进过一次箭头不再出
## 3 结尾：大门开了（签过到、写过悄悄话）从迎宾院大门出来回停车场，金箭头指自己的车；走到车旁说送别那两句，箭头收
## 4 进过迎宾院的再开游戏照旧从迎宾院进；没吃完就往外走不拦着、不指车
## （10/4 连图 02 E 改：门楼挪到前门那块；停车场东口去迎宾院、东南口去前门、北口去后花园，路东原来那条湖拿掉了；
##   迎宾院大门出去先到前门再往西进停车场。10/4 方案 C：停车场整块左右翻，路西车位东，两个口在西边，前门往东进停车场；每次进山庄都开车进来停车场下车）
## 用法：Godot --headless --path . --script res://tools/test_parking.gd ；最后一行 RESULT PASS 才算过

const CourtCopy = preload("res://scripts/court_copy.gd")
var m
var started := false
var ok := true

func _initialize() -> void:
    m = load("res://scripts/main.gd").new()
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

func frames(n: int) -> void:
    for i in n:
        await process_frame

## 走过去：从离点 dist 远的地方（point 的 side 那边）出发，走进那个点的半径，等换画布或者 cond 成立
func walk_in(c, id: String, side: Vector2, until: Callable) -> bool:
    var pt: Vector2 = c.points[id]["pos"]
    c.reset_to(pt + side)
    await frames(2)
    c.go_to(pt)
    for i in 600:
        await process_frame
        if until.call():
            return true
    return false

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    var cs = m.court_save
    cs.local_path = "user://test_parking_court.json"
    cs.welcomed = false
    cs.signed_in = false
    cs.whisper_done = false
    cs.court_seen = false
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    print("1 摆法")
    m.ensure_canvas("parking")
    var p = m.parking
    var items: Dictionary = {}
    for it in p.cfg["items"]:
        items[str(it["id"])] = it
    var want := {"car_bmw240": [4.45, 1.77, 1.40], "car_brz": [4.26, 1.78, 1.31], "car_p911": [4.52, 1.85, 1.30], "car_h6": [4.65, 1.89, 1.73]}
    for id in want:
        var it: Dictionary = items.get(id, {})
        var r: Array = it.get("rect", [0, 0, 0, 0])
        var dims := Vector3(float(r[2]) - float(r[0]), float(r[3]) - float(r[1]), float(it.get("h", 0)))
        var w: Array = want[id]
        var real := Vector3(float(w[1]) * 48.0, float(w[0]) * 32.0, float(w[2]) * 48.0)
        check("%s 在、照真车尺寸（宽 %d 前后 %d 高 %d，真车 %.0f/%.0f/%.0f）" % [str(it.get("scale", {}).get("name", id)), dims.x, dims.y, dims.z, real.x, real.y, real.z],
            not it.is_empty() and absf(dims.x - real.x) <= 1.0 and absf(dims.y - real.y) <= 1.0 and absf(dims.z - real.z) <= 1.0)
    var road_bad := 0
    for y in range(300, int(p.cfg["size"][1]) - 24, 12):
        if not p._free(Vector2(float(p.cfg["size"][0]) - 690.0, y)):   # 10/4 方案 C 整块左右翻：路在西边（正中离东边 690；第 68 版往西放大 384，路正中 x 718）
            road_bad += 1
    check("路正中从大门一直到南边都能走（挡住 %d 格）" % road_bad, road_bad == 0)
    # 第 68 版：西边两个口改成去喷泉广场、去前门；去迎宾院挪到北墙（停车场往西放大，在迎宾院正下方）
    check("原来的湖拿掉了，西边两个口（喷泉广场、前门）、北墙两道门（迎宾院、后花园）、南边两间小屋都在", p.points.has("to_court") and p.points.has("to_frontgate") and p.points.has("to_garden") and p.points.has("to_plaza")
        and p.points.has("toilet") and p.points.has("trash") and not p.points.has("to_lake"))
    var path: Array = p.find_path(p.SPAWN, p.points["to_court"]["pos"])
    check("从自己的车走得到去迎宾院的口", not path.is_empty() and (path[path.size() - 1] as Vector2).distance_to(p.points["to_court"]["pos"]) <= float(p.points["to_court"]["r"]))
    path = p.find_path(p.arrival_at("to_frontgate"), p.points["my_car"]["pos"])
    check("从前门进来走得到自己的车旁", not path.is_empty() and (path[path.size() - 1] as Vector2).distance_to(p.points["my_car"]["pos"]) <= float(p.points["my_car"]["r"]))
    var far := 0
    for id in items:
        if not str(id).begins_with("car_"):
            continue
        var r2: Array = items[id]["rect"]
        var near := false
        for yy in range(int(r2[1]) - 24, int(r2[3]) + 25, 6):
            for xx in range(int(r2[0]) - 24, int(r2[2]) + 25, 6):
                if p._free(Vector2(xx, yy)):
                    near = true
        if not near:
            far += 1
    check("每辆车跟前都走得到（绕着车走，走不到的 %d 辆）" % far, far == 0)

    print("2 开头：从停车场开始")
    await m._start_play()
    await frames(10)
    check("没进过迎宾院：选完形象站在停车场（%s）" % m.state, m.state == "parking" and p.pos.distance_to(p.SPAWN) < 2.0)
    check("站在自己的车旁边（离车 %.0f）" % p.SPAWN.distance_to(Vector2((float(items["car_mine"]["rect"][0]) + float(items["car_mine"]["rect"][2])) * 0.5, (float(items["car_mine"]["rect"][1]) + float(items["car_mine"]["rect"][3])) * 0.5)),
        p.SPAWN.x < float(items["car_mine"]["rect"][0]) and float(items["car_mine"]["rect"][0]) - p.SPAWN.x < 40.0)   # 方案 C：下车站在车西边
    var ar: Polygon2D = p.guide_arrow
    var to_gate: Vector2 = p.points["to_court"]["pos"] - (p.pos - Vector2(0, p.GUIDE_UP))
    check("金箭头出来了、指着大门（差 %.0f 度）" % rad_to_deg(absf(angle_difference(ar.rotation, to_gate.angle()))), ar.visible and absf(angle_difference(ar.rotation, to_gate.angle())) < 0.1)
    var got: bool = await walk_in(p, "to_court", Vector2(0, 90), func(): return m.state == "court" and not m.switching)
    check("走进北墙那道门到了迎宾院", got)
    await frames(5)
    check("站在迎宾院大门里边（%s）" % m.court.pos, m.court.pos.distance_to(m.court.SPAWN) < 2.0)
    check("第一次进来说「%s」" % m.said_raw, m.dialog.visible and m.said_raw == m.LINE_ARRIVE)
    check("记下进过迎宾院了", cs.court_seen)
    m.dialog.visible = false

    print("3 结尾：吃完席回车上")
    cs.signed_in = true
    cs.whisper_done = true
    m._update_gate()
    got = await walk_in(m.court, "gate", Vector2(0, -100), func(): return m.state == "parking" and not m.switching)
    check("大门开了，走出大门直接回到停车场（第 68 版：不过前门）", got)
    await frames(5)
    check("站在北墙去迎宾院那道门里边（%s）" % p.pos, p.pos.distance_to(p.arrival_from("court")) < 2.0)
    check("金箭头这回指自己的车", p.car_hint and ar.visible and absf(angle_difference(ar.rotation, (p.points["my_car"]["pos"] - (p.pos - Vector2(0, p.GUIDE_UP))).angle())) < 0.1)
    got = await walk_in(p, "my_car", Vector2(0, -120), func(): return m.dialog.visible)
    var bye: String = CourtCopy.text("gate_bye")
    check("走到车旁说送别：%s" % m.said_raw.replace("\n", " / "), got and m.said_raw.begins_with(bye))
    await frames(3)
    check("箭头收了", not p.car_hint and not ar.visible)
    m.dialog.visible = false

    print("4 再开游戏、没吃完就走")
    await m._start_play()
    await frames(5)
    check("进过迎宾院的再开游戏：也是开车进来停车场下车（%s），不指大门" % m.state, m.state == "parking" and not p.gate_hint)
    got = await walk_in(p, "to_court", Vector2(0, 90), func(): return m.state == "court" and not m.switching)
    m.dialog.visible = false
    cs.whisper_done = false
    m._update_gate()
    m.court.reset_to(m.court.SPAWN + Vector2(0, -120))
    got = await walk_in(m.court, "gate", Vector2(0, -100), func(): return m.state == "parking" and not m.switching)
    check("没吃完往外走：不拦着，出大门回到停车场", got)
    await frames(3)
    check("不指车、也不再指大门", not p.car_hint and not p.gate_hint and not ar.visible)
    check("提醒那句还是【待补】，不出", CourtCopy.placeholder(CourtCopy.text("gate_leave_early")) and not m.dialog.visible)
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
