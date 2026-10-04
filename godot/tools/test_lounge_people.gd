extends SceneTree
## 验收：休息间人物样板的「系统」部分（docs/人物新做法-休息间样板-v0.1.md 第 2、3、4 节，01 F 10/4）。无界面跑整个 main.gd。
##   1 休息间四位坐着（奶奶、爷爷北边沙发，叔叔、阿姨茶座），座位都有起来能站的空地、从后厅进口走得到
##   2 冒泡：两组轮流冒，一组同时只冒一个；话里每个字字体都有
##   3 坐下：每个空座位走到跟前出「坐下」，坐上去位置、朝向对，「起来」站回跟前；NPC 占着的不出「坐下」；坐着推摇杆站起来
##   4 说话：点 NPC（屏幕上点他本人）→ 走过去 → 弹对话框（名字牌、上半身人物图、一句句点下去，说完收、能走）；说话时他那组不冒泡
##   5 身份卡：全身人物图 + 称呼；关上回到对话框
##   6 坐在奶奶旁边直接「跟奶奶聊聊」
##   7 代码小人（10/4 第二步）：坐着放坐姿格（20～27）、脚踩座位前沿；说话时放说话格（18、19）；叔叔隔一阵起身走一圈（四向走路格、
##     站定放待机格 16、17）再坐回去
## 用法：Godot --headless --path . --script res://tools/test_lounge_people.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0

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

func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

func walk_to(target: Vector2, secs := 20.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_lounge_court.json"
    m.games_save.local_path = "user://test_lounge_games.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await process_frame
    var b = m.backhall
    b.walking_enabled = true
    var life = b.lounge
    var ui = m.lounge_ui
    tick(2)

    print("1 四位、座位")
    var who := {}
    for id in ["lounge_09", "lounge_10", "lounge_05", "lounge_06"]:
        var s: Sprite2D = b.npc_nodes.get(id)
        who[id] = s != null and s.hframes == 16 and s.vframes == 2 and s.frame >= 20 and s.frame <= 27 and s.position.x > 864 and s.position.x < 1200
    check("四位代码小人坐在休息间、放坐姿格（%s）" % [who], not who.values().has(false) and life.people.size() == 4)
    check("奶奶、爷爷在北边沙发，叔叔、阿姨在茶座", life.person("lounge_09")["seat"] == "sofa_l" and life.person("lounge_10")["seat"] == "sofa_r"
        and life.person("lounge_05")["seat"] == "west_chair_w" and life.person("lounge_06")["seat"] == "west_chair_e")
    var bad: Array = []
    for s in life.seats:
        var st: Vector2 = s["stand"]
        var path: Array = b.find_path(b.SPAWN, st)
        if st == Vector2.ZERO or not b._free(st) or path.is_empty() or (path[path.size() - 1] as Vector2).distance_to(st) > 8.0 or st.distance_to(Vector2(s["x"], s["seat_y"])) > 70.0:
            bad.append(s["id"])
    check("%d 个座位都有起来站的空地、从后厅进口走得到（不行的 %s）" % [life.seats.size(), bad], life.seats.size() >= 12 and bad.is_empty())

    print("2 冒泡")
    var seen := {}
    var max_per_group := 0
    for i in int(16.0 / DT):
        tick(1)
        var sofa := 0
        var tea := 0
        for id in ["lounge_09", "lounge_10", "lounge_05", "lounge_06"]:
            var tx: String = life.bubble_text(id)
            if tx != "":
                seen[id] = true
                if id in ["lounge_09", "lounge_10"]:
                    sofa += 1
                else:
                    tea += 1
        max_per_group = maxi(max_per_group, maxi(sofa, tea))
    check("16 秒里四位都冒过话（%s）" % [seen.keys()], seen.size() == 4)
    check("一组同时只冒一个（最多 %d）" % max_per_group, max_per_group == 1)
    var miss := ""
    var f: Font = m.font
    for g in life.data["chat"]:
        for l in g["lines"]:
            for ch in str(l[1]):
                if not f.has_char(ch.unicode_at(0)):
                    miss += ch
    for id in life.data["people"]:
        for l in life.data["people"][id]["talk"]:
            for ch in str(l["text"]):
                if not f.has_char(ch.unicode_at(0)):
                    miss += ch
    for k in life.data["buttons"]:
        for ch in str(life.data["buttons"][k]).replace("%s", ""):
            if not f.has_char(ch.unicode_at(0)):
                miss += ch
    check("冒泡、对话、按钮上的字字体都有（缺 %s）" % miss, miss == "")

    print("3 坐下")
    var occupied_ok := true
    for s in life.seats:
        if str(s.get("npc", "")) == "":
            continue
        b.reset_to(s["stand"])
        tick(2)
        var ns: Dictionary = life.near_seat()
        if not ns.is_empty() and str(ns.get("npc", "")) != "":
            occupied_ok = false
    check("NPC 占着的座位不出「坐下」", occupied_ok)
    var sat_bad: Array = []
    var sat_n := 0
    for s in life.seats:
        if str(s.get("npc", "")) != "":
            continue
        b.reset_to(s["stand"])
        tick(2)
        var ns: Dictionary = life.near_seat()
        if ns.is_empty() or not ui.seat_btn.visible or ui.seat_btn.text != "坐下":
            sat_bad.append("%s 没出坐下" % s["id"])
            continue
        if ns["id"] != s["id"]:
            continue   # 两个座位跟前同一块空地（沙发、长沙发），坐最近那个
        ui._on_seat()
        tick(30)
        sat_n += 1
        if not (b.seated and b.pos == Vector2(s["x"], s["y"]) and b.face == str(s["face"]) and ui.seat_btn.text == "起来" and life.my_seat == s["id"]):
            sat_bad.append("%s 坐得不对 %s %s" % [s["id"], b.pos, b.face])
        ui._on_seat()
        tick(2)
        if b.seated or b.pos != s["stand"] or ui.seat_btn.text != "坐下" or life.my_seat != "":
            sat_bad.append("%s 起来不对 %s" % [s["id"], b.pos])
    check("空座位都能坐、能起来（坐过 %d 个，不对的 %s）" % [sat_n, sat_bad], sat_bad.is_empty() and sat_n >= 9)
    var sofa_m: Dictionary = life.seat_by_id("sofa_m")
    b.reset_to(sofa_m["stand"])
    tick(2)
    life.sit(sofa_m)
    tick(30)
    var seated_y: float = b.player.position.y + b.player.offset.y * b.player.scale.y
    check("坐沙发中间：朝下、上半身画在椅面上（脚点 %.0f，画的中心 %.0f）" % [b.pos.y, seated_y], b.seated and b.face == "down" and seated_y < float(sofa_m["seat_y"]))
    b.stick = Vector2(0, 1)
    tick(10)
    b.stick = Vector2.ZERO
    tick(2)
    check("坐着推摇杆就站起来，按钮跟着变（%s）" % ui.seat_btn.text, not b.seated and life.my_seat == "" and ui.seat_btn.text != "起来")

    print("4 说话")
    b.reset_to(Vector2(1032, 640))   # 10/4 方案 C：后厅四间整间平移（化妆间 +1195、休息室 +528、麻将室 −144），下面的坐标照平移后的写
    tick(2)
    var p06: Dictionary = life.person("lounge_06")
    var at: Vector2 = (p06["head"] + p06["foot"]) * 0.5
    var screen: Vector2 = b.get_viewport().get_canvas_transform() * at
    b.tap(screen)
    for i in int(20.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    check("屏幕上点阿姨：走过去、弹对话框（站在 %s）" % b.pos, ui.talk_box.visible and ui.talk_id == "lounge_06" and b.pos.distance_to(p06["stand"]) <= 34.0)
    var s06: Sprite2D = b.npc_nodes["lounge_06"]
    check("跟阿姨说话时她站起来放说话格（第 %d 格）" % s06.frame, s06.frame == 18 or s06.frame == 19)
    check("名字牌「%s」、不能走、上半身人物图（%s）" % [ui.name_label.text, ui.portrait.texture.region if ui.portrait.texture else null],
        ui.name_plate.visible and ui.name_label.text == "阿姨" and not b.walking_enabled and ui.portrait.texture != null
        and ui.portrait.texture.region.size.y < 60.0)
    tick(int(4.0 / DT))
    check("跟阿姨说话时她那组不冒泡", life.bubble_text("lounge_05") == "" and life.bubble_text("lounge_06") == "")
    var texts: Array = [ui.line_label.text]
    var side_ok := false
    var n: int = (p06["talk"] as Array).size()
    for i in n - 1:
        ui.next_line()
        texts.append(ui.line_label.text)
        if str(ui.portrait.get_meta("pose")) == "side":
            side_ok = ui.portrait.texture.region.position.x == 4.0 * 64.0
    check("一句句点下去（%s）；侧身那句换侧身的图" % [texts], texts.size() == n and texts[0] == str(p06["talk"][0]["text"]) and side_ok)
    ui.next_line()
    check("说完对话框收了、又能走", not ui.talk_box.visible and not ui.name_plate.visible and b.walking_enabled and life.talking == "")
    tick(2)
    check("阿姨说完坐回去（第 %d 格）" % s06.frame, s06.frame >= 20 and s06.frame <= 27)

    print("5 身份卡")
    life.request_talk("lounge_05")
    for i in int(20.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    ui.card_btn.pressed.emit()
    tick(1)
    var body: TextureRect = ui.card.find_child("full_body", true, false) if ui.card != null else null
    check("身份卡开了：全身人物图（%s）" % [body.texture.region if body and body.texture else null],
        body != null and body.texture != null and body.texture.region.size.y >= 80.0)
    ui.next_line()
    check("身份卡开着点对话框不翻句", ui.line_i == 0)
    ui.close_card()
    check("关上身份卡回到对话框", ui.card == null and ui.talk_box.visible)
    ui.close_talk()

    print("6 坐在奶奶旁边聊")
    b.reset_to(sofa_m["stand"])
    tick(2)
    life.sit(sofa_m)
    tick(30)
    check("坐着出「%s」" % ui.talk_btn.text, ui.talk_btn.visible and ui.talk_btn.text.begins_with("跟") and ui.talk_btn.text.ends_with("聊聊"))
    ui.talk_btn.pressed.emit()
    tick(1)
    check("坐着点就直接说，人还坐着", ui.talk_box.visible and b.seated)
    ui.close_talk()
    m._switch_canvas("banquet")
    tick(5)
    check("离开后厅按钮、对话框都收", not ui.seat_btn.visible and not ui.talk_btn.visible and not ui.talk_box.visible)

    print("7 叔叔起身走一圈")
    m._show_canvas("backhall")
    m._goto("backhall")
    var u: Dictionary = life.person("lounge_05")
    var su: Sprite2D = b.npc_nodes["lounge_05"]
    for i in int(60.0 / DT):   # 前面几段里他可能已经起身了：先等他坐回去
        tick(1)
        if str(u["mode"]) == "sit" and (u["foot"] as Vector2) == u["home"] and (u["legs"] as Array).is_empty():
            break
    u["wait"] = 0.0
    var faces := {}
    var idle_seen := false
    var left_home := false
    var back := false
    for i in int(90.0 / DT):
        tick(1)
        if str(u["mode"]) == "walk":
            faces[str(u["face"])] = true
            if su.frame > 15:
                faces["错格"] = true
        if str(u["mode"]) == "idle" and (su.frame == 16 or su.frame == 17):
            idle_seen = true
        if (u["foot"] as Vector2) != u["home"]:
            left_home = true
        elif left_home and str(u["mode"]) == "sit":
            back = true
            break
    check("叔叔起身走了（走路朝向 %s，走路只放第一行）" % [faces.keys()], left_home and faces.size() >= 3 and not faces.has("错格"))
    check("在唱片机、电视前站着放待机格", idle_seen)
    check("走回来坐下（%s，第 %d 格）" % [u["foot"], su.frame], back and su.frame >= 20 and su.frame <= 27)
    check("他走开时座位还是他的（玩家不能坐）", str(life.seat_by_id("west_chair_w").get("npc", "")) == "lounge_05")

    DirAccess.remove_absolute("user://test_lounge_court.json")
    DirAccess.remove_absolute("user://test_lounge_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
