extends SceneTree
## 第 68 版下车提示 + 金箭头 + 老存档进停车场不卡墙（07 做，阿鱼：「停车场出来之后，就可以去迎宾院签到……有个提示语牵引他」），03 自己重测（01 H 10/4 派，不改游戏代码；不看 07 的 test_drive68，另起量法）：
##   1 四种存档（什么都没有 / 进过迎宾院 / 签过到 / 签过到也写过悄悄话）各开一趟车下车：停车场出生点能站、能走到每一个口（迎宾院、广场、前门、后花园）和自己的车；
##     没签到的（前两种）：顶上说「出阁宴在宴会厅 先去迎宾院签个到」（字不含「待」「预留」）、金箭头出来、转的角度指着去迎宾院那道门（差 < 6 度）；
##     签过到的：不说、箭头不出
##   2 没签到的：走开再走回来箭头还在；走进迎宾院再从大门出来回停车场（没吃完、没签到）箭头还指迎宾院；签完到（记 signed_in）再从大门出来：箭头收了（吃完了的指自己的车）
##   3 老的落点兜底：停车场的 FROM_* 常量、自己的车位点、出生点都在新停车场（往西放大 384）里能站、不在墙里
##   4 提示那句：存在于 lines.json、不超过 20 个字、说的时间够读（≥ 3 秒）
## 用法：Godot --headless --path . --script res://tools/test_park_sign_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const SAVE := "user://test_ps_court.json"

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

func frames(n: int) -> void:
    for i in n:
        await process_frame

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func set_save(d: Dictionary) -> void:
    var f := FileAccess.open(SAVE, FileAccess.WRITE)
    f.store_string(JSON.stringify(d))
    f.close()
    m.court_save.local_path = SAVE
    m.court_save.load_local()

func start_play() -> void:
    m.dialog.visible = false
    m.say_token += 1
    m._start_play()
    for i in 600:
        await process_frame
        if not m.driving and m.state == "parking" and not m.switching:
            break
    await frames(6)

func walk_to(target: Vector2, secs := 40.0) -> void:
    var c = m.cv
    c.walking_enabled = true
    c.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv != c or c.path.is_empty():
            break
    for i in 60:
        if not m.switching:
            break
        await process_frame

func arrow_diff_deg(pk) -> float:
    var to: Vector2 = pk.points["to_court"]["pos"] - (pk.pos - Vector2(0, pk.GUIDE_UP))
    return rad_to_deg(absf(angle_difference(pk.guide_arrow.rotation, to.angle())))

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.cloud.fake_no_news = true
    m.nickname = "小李"
    m.games_save.local_path = "user://test_ps_games.json"
    m.ensure_canvas("parking")
    var pk = m.parking
    var want_text: String = CourtCopy_text()

    print("1 四种存档下车")
    var variants := [
        ["什么都没有", {}, false],
        ["进过迎宾院没签到", {"welcomed": true, "court_seen": true}, false],
        ["签过到", {"welcomed": true, "court_seen": true, "signed_in": true}, true],
        ["签过到也写过悄悄话", {"welcomed": true, "court_seen": true, "signed_in": true, "whisper_done": true}, true],
    ]
    for v in variants:
        set_save(v[1])
        await start_play()
        var signed: bool = v[2]
        var free_ok: bool = pk._free(pk.pos) and pk.pos == pk.SPAWN
        var reach: Array = []
        for pid in ["to_court", "to_plaza", "to_frontgate", "to_garden", "my_car"]:
            if not pk.points.has(pid):
                reach.append(pid + "（口不存在）")
                continue
            var path: Array = pk.find_path(pk.pos, pk.points[pid]["pos"])
            if path.is_empty() or (path[path.size() - 1] as Vector2).distance_to(pk.points[pid]["pos"]) > float(pk.points[pid]["r"]) + 2.0:
                reach.append(pid)
        var said: bool = m.dialog.visible and m.dialog_text.text == want_text
        var arrow_on: bool = pk.guide_arrow.visible
        var diff := arrow_diff_deg(pk) if arrow_on else -1.0
        if signed:
            check("%s：下车站在出生点能站、走得到各口（走不到 %s）；不说提示（说了 %s）、箭头不出（%s）" % [v[0], str(reach), str(said), str(arrow_on)], free_ok and reach.is_empty() and not said and not arrow_on and not pk.gate_hint)
        else:
            check("%s：下车站在出生点能站、走得到各口（走不到 %s）；说「%s」（%s）、箭头出来指迎宾院那道门（差 %.1f 度）" % [v[0], str(reach), m.dialog_text.text, str(said), diff], free_ok and reach.is_empty() and said and arrow_on and diff < 6.0 and pk.gate_hint)

    print("2 没签到：走开再回来、进迎宾院再回来")
    set_save({"welcomed": true})
    await start_play()
    await walk_to(pk.SPAWN + Vector2(-200, -60))
    await walk_to(pk.SPAWN)
    tick(3)
    check("走开再走回来：箭头还在（差 %.1f 度）" % arrow_diff_deg(pk), pk.guide_arrow.visible and pk.gate_hint and arrow_diff_deg(pk) < 6.0)
    await walk_to(pk.points["to_court"]["pos"])
    check("走进北墙那道门到了迎宾院（%s）、站在大门里边" % m.state, m.state == "court" and m.court.pos.distance_to(m.court.SPAWN) < 2.0)
    tick(60)
    await walk_to(m.court.SPAWN + Vector2(0, -200))
    await walk_to(m.court.spot_pos("gate"))
    tick(3)
    var near_door: bool = pk.pos.distance_to(pk.points["to_court"]["pos"]) <= pk.GUIDE_NEAR   # 从大门出来站在那道门旁边，离得太近箭头先不出，走开才出
    var hint_on: bool = pk.gate_hint
    await walk_to(pk.SPAWN)
    tick(3)
    check("没签到、从大门出来回停车场（%s，站在门旁 %s）：还要指迎宾院（gate_hint %s）、走开以后箭头出来（%s）" % [m.state, str(near_door), str(hint_on), str(pk.guide_arrow.visible)], m.state == "parking" and hint_on and pk.guide_arrow.visible and arrow_diff_deg(pk) < 6.0)
    m.court_save.signed_in = true
    m.court_save.whisper_done = true
    m._update_gate()
    await walk_to(pk.points["to_court"]["pos"])
    tick(60)
    await walk_to(m.court.SPAWN + Vector2(0, -200))
    await walk_to(m.court.spot_pos("gate"))
    tick(3)
    check("签完到（也写了悄悄话）再从大门出来：不指迎宾院了（gate_hint %s）、指自己的车（car_hint %s）" % [str(pk.gate_hint), str(pk.car_hint)], m.state == "parking" and not pk.gate_hint and pk.car_hint)

    print("3 老的落点兜底")
    var olds := {"FROM_COURT": pk.FROM_COURT, "FROM_LAKE": pk.FROM_LAKE, "SPAWN": pk.SPAWN, "my_car": pk.points["my_car"]["pos"]}
    var old_bad: Array = []
    for k in olds:
        var p: Vector2 = olds[k]
        if p == Vector2.ZERO:
            continue
        if not pk._free(p):
            var near: Vector2 = pk.nearest_free(p)
            old_bad.append("%s %s 站不了（72 像素内最近能站 %s）" % [k, str(p), str(near)])
    for pid in pk.points:
        if str(pk.points[pid]["to"]) != "":
            var land: Vector2 = pk.arrival_at(pid)
            if land == Vector2.ZERO or not pk._free(land):
                old_bad.append("落点 %s %s 站不了" % [pid, str(land)])
    for b in old_bad:
        print("    ", b)
    check("停车场的 FROM_* 常量、出生点、自己的车位点、每个口的落点都能站（%d 处站不了；常量 0 视为没设）" % old_bad.size(), old_bad.is_empty())

    print("4 提示那句")
    var lj = JSON.parse_string(FileAccess.get_file_as_string("res://assets/entrance/lines.json"))
    var txt := ""
    if lj is Dictionary and (lj["lines"] as Dictionary).has("park_sign"):
        txt = str(lj["lines"]["park_sign"]["text"])
    var hold: float = 2.4 + txt.length() * 0.09
    check("lines.json 有 park_sign：「%s」（%d 个字、不含「待」「预留」、说 %.1f 秒）" % [txt, txt.length(), hold], txt != "" and txt.length() <= 20 and not txt.contains("待") and not txt.contains("预留") and hold >= 3.0)

    print("5 下车那一屏：路牌不压「点地面走路」提示、牌子之间不叠、不盖自己（手机 540×960、长屏 585×1266 各一遍）")
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        set_save({"welcomed": true, "court_seen": true})
        m.hint_done = false
        await start_play()
        await frames(10)
        var hint_shown: bool = m.hint != null and m.hint.visible
        var hr: Rect2 = m.hint.get_global_rect()
        var me: Vector2 = to_screen(pk.pos, pk)
        var body := Rect2(me.x - 20.0, me.y - 80.0, 40.0, 80.0)
        var scr := Rect2(Vector2.ZERO, Vector2(sz))
        var lab_rects: Array = []
        var hit_hint: Array = []
        var on_body: Array = []
        for lb in pk.labels.get_children():
            if not lb is Label or not (lb as Label).visible:
                continue
            var l := lb as Label
            var home_x: float = float(l.get_meta("home")) if l.has_meta("home") else l.position.x
            var a: Vector2 = to_screen(Vector2(home_x, l.position.y), pk)
            var z: Vector2 = to_screen(Vector2(home_x, l.position.y) + l.size, pk)
            var r := Rect2(a, z - a)
            if not r.intersects(scr):
                continue   # 这一屏里看不到的牌不算
            lab_rects.append([str(l.text), r])
            if hint_shown and r.intersects(hr):
                hit_hint.append("「%s」%s 压提示框 %s" % [l.text, str(r), str(hr)])
            if r.intersects(body):
                on_body.append("「%s」盖住自己" % l.text)
        for hs in pk.room_signs:   # 小屋门口的牌（公共洗手间、垃圾杂物处）是另一种牌，不在 labels 里
            var rl = (hs as Node2D).get_child(0)
            if not rl is Label:
                continue
            var rp: Vector2 = (hs as Node2D).position + (rl as Label).position
            var ra: Vector2 = to_screen(rp, pk)
            var rz: Vector2 = to_screen(rp + (rl as Label).size, pk)
            var rr := Rect2(ra, rz - ra)
            if not rr.intersects(scr):
                continue
            lab_rects.append([str((rl as Label).text), rr])
            if hint_shown and rr.intersects(hr):
                hit_hint.append("「%s」%s 压提示框 %s" % [(rl as Label).text, str(rr), str(hr)])
            if rr.intersects(body):
                on_body.append("「%s」盖住自己" % (rl as Label).text)
        var overlap: Array = []
        for i in lab_rects.size():
            for j in range(i + 1, lab_rects.size()):
                if (lab_rects[i][1] as Rect2).intersects(lab_rects[j][1]):
                    overlap.append("「%s」×「%s」" % [lab_rects[i][0], lab_rects[j][0]])
        var names: Array = lab_rects.map(func(x): return str(x[0]))
        var toilet_in: bool = names.has("公共洗手间") or names.has("垃圾杂物处")
        for x in hit_hint + on_body + overlap:
            print("    ", x)
        check("%s：下车这一屏看得见的牌 %s，提示框在 %s；压提示框 %d、盖自己 %d、牌子互相叠 %d 对；洗手间 / 杂物处牌在这屏里 %s（只露到屏边可以，不压提示框、不盖人就行）" % [str(sz), str(names), str(hint_shown), hit_hint.size(), on_body.size(), overlap.size(), str(toilet_in)], hint_shown and hit_hint.is_empty() and on_body.is_empty() and overlap.is_empty())
    get_root().size = Vector2i(540, 960)

    DirAccess.remove_absolute(SAVE)
    DirAccess.remove_absolute("user://test_ps_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

func CourtCopy_text() -> String:
    var lj = JSON.parse_string(FileAccess.get_file_as_string("res://assets/entrance/lines.json"))
    return str(lj["lines"]["park_sign"]["text"]) if lj is Dictionary and (lj["lines"] as Dictionary).has("park_sign") else ""

## 屏幕坐标（窗口像素）：世界点 → 子视口 → 窗口
func to_screen(wp: Vector2, b) -> Vector2:
    var sv: SubViewport = m.view.get_child(0)
    var cc: Vector2 = b.cam.get_screen_center_position()
    var z: float = b.cam.zoom.x
    var in_sv := (wp - cc) * z + Vector2(sv.size) * 0.5
    return in_sv * (Vector2(get_root().size) / Vector2(sv.size))
