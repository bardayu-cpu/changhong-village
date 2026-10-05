extends SceneTree
## 休息间人物样板系统（build57 f9216c6，第 59 版 529d033）的功能测试（01 F 10/4 派，03 写）。不改游戏代码；存档指到临时文件。
## 阿鱼 10/4「休息厅所有的凳子都是可以坐下的，然后，玩家是可以去坐下的」。跟 02 的 test_lounge_people 不重复，这里是独立再核：
##   1 座位：layout 的 seats 15 个。每个座位的「起来站的空地」(stand)：能站、从后厅进口摇杆走得到、站上去 near_seat() 指的就是这个座位（不串到邻座）
##   2 NPC 占着的座位（4 个）：sit() 不坐、站到它跟前 near_seat() 不指它；空座位 11 个：走到跟前「坐下」按钮出、点了坐上去（位置、朝向、坐姿抬高对）、
##     按钮变「起来」、点了站起来站回空地、再坐再推摇杆也站起来
##   3 点人说话：4 位 NPC 各点一次（屏幕上点他本人）→ 走过去 → 弹对话框（名字牌、人物图、每句话对 lounge.json）→ 点完收、能走；身份卡开关；坐在他旁边直接聊
##   4 冒泡：两组各一个气泡一次；字都有；气泡在画布里；气泡下面点地面照样走（不挡操作）；说话那一组停
## 用法：Godot --headless --path . --script res://tools/test_lounge_people_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 60.0
const STUCK_SECS := 2.0
const MAX_LEG := 90.0

var m
var started := false
var ok := true
var b
var life
var ui

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(300.0).timeout.connect(func():
        print("RESULT FAIL 300 秒没跑完")
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
        b._process(DT)
        ui.sync()

func reenter() -> void:
    m.switching = false
    if m.state != "backhall":
        m._show_canvas("backhall")
        m._goto("backhall")
    b.walking_enabled = true
    b.stick = Vector2.ZERO
    if ui.is_open():
        ui.hide_all()

func walk(target: Vector2) -> Dictionary:
    var path: Array = b.find_path(b.pos, target)
    if path.is_empty():
        return {"ok": false, "err": "寻路没路"}
    b.path.clear()
    var wi := 0
    var best := INF
    var noprog := 0.0
    var total := 0.0
    while wi < path.size():
        var wp: Vector2 = path[wi]
        var d: Vector2 = wp - b.pos
        if d.length() < 3.0:
            wi += 1
            best = INF
            noprog = 0.0
            continue
        b.stick = d.normalized()
        tick(1)
        total += DT
        var nd: float = (wp - b.pos).length()
        if nd < best - 0.5:
            best = nd
            noprog = 0.0
        else:
            noprog += DT
        if noprog >= STUCK_SECS or total > MAX_LEG:
            b.stick = Vector2.ZERO
            return {"ok": false, "err": "卡住", "at": b.pos, "wp": wp}
    b.stick = Vector2.ZERO
    return {"ok": true, "secs": total}

## 点屏幕上世界里的一点（照 backhall.tap 的换算）
func tap_world(p: Vector2) -> void:
    var screen: Vector2 = b.get_viewport().get_canvas_transform() * p
    b.tap(screen)

func run_until_idle(secs := 20.0) -> void:
    for i in int(secs / DT):
        tick(1)
        if b.path.is_empty() and life.pending_talk == "":
            break

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_lp_court.json"
    m.games_save.local_path = "user://test_lp_games.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    b = m.backhall
    life = b.lounge
    ui = m.lounge_ui
    ui.attach(life)
    b.walking_enabled = true
    var door := Vector2(1032, 690)   # 10/4 方案 C：后厅四间整间平移（化妆间 +1195、休息室 +528、麻将室 −144），下面的坐标照平移后的写

    print("1 座位（%d 个）" % life.seats.size())
    check("layout 里 15 个座位、4 个有 NPC 占着", life.seats.size() == 15 and life.seats.filter(func(s): return str(s.get("npc", "")) != "").size() == 4)
    var bad_stand: Array = []
    var bad_walk: Array = []
    var bad_near: Array = []
    var stand_close: Array = []
    for s in life.seats:
        var st: Vector2 = s["stand"]
        if st == Vector2.ZERO or not b._free(st):
            bad_stand.append(str(s["id"]))
            continue
        reenter()
        b.reset_to(door)
        var r := walk(st)
        if not (r["ok"] and (b.pos - st).length() <= 10.0):
            bad_walk.append("%s %s" % [s["id"], str(r)])
        b.reset_to(st)
        b.path.clear()
        var ns: Dictionary = life.near_seat()
        var npc_seat: bool = str(s.get("npc", "")) != ""
        if npc_seat:
            if ns.has("id") and str(ns["id"]) == str(s["id"]):
                bad_near.append("%s（NPC 占着的）站到跟前 near_seat 指它自己" % s["id"])
        elif not (ns.has("id") and str(ns["id"]) == str(s["id"])):
            bad_near.append("%s 站到跟前 near_seat 指 %s" % [s["id"], str(ns.get("id", "没有"))])
        for s2 in life.seats:
            if s2 != s and (s2["stand"] as Vector2).distance_to(st) < 12.0:
                stand_close.append("%s 跟 %s 的站位只差 %.0f" % [s["id"], s2["id"], (s2["stand"] as Vector2).distance_to(st)])
    check("15 个座位的「起来站的空地」都能站（不能站的 %s）" % str(bad_stand), bad_stand.is_empty())
    check("从后厅进口摇杆走得到每个座位跟前（不通的 %s）" % str(bad_walk), bad_walk.is_empty())
    check("站到座位跟前，near_seat 指的就是它（NPC 占着的不指）（对不上的 %s）" % str(bad_near), bad_near.is_empty())
    print("    站位靠得很近（<12 像素）的座位对：%s" % str(stand_close))

    print("2 坐下 / 起来")
    var bad_sit: Array = []
    var n_sit := 0
    for s in life.seats:
        if str(s.get("npc", "")) != "":
            # NPC 占着的：sit() 不坐
            reenter()
            b.reset_to(s["stand"])
            life.sit(s)
            if b.seated or life.my_seat != "":
                bad_sit.append("%s（NPC 占着的）居然坐上了" % s["id"])
                b.stand_up()
            continue
        reenter()
        b.reset_to(door)
        var r := walk(s["stand"])
        if not r["ok"]:
            bad_sit.append("%s 走不到跟前" % s["id"])
            continue
        tick(2)
        if not (ui.seat_btn.visible and ui.seat_btn.text == ui._txt("sit")):
            bad_sit.append("%s 走到跟前没出「坐下」（按钮 %s %s）" % [s["id"], ui.seat_btn.visible, ui.seat_btn.text])
            continue
        ui.seat_btn.pressed.emit()
        tick(90)    # 坐下的滑动 1 秒多
        n_sit += 1
        var seat_pos := Vector2(float(s["x"]), float(s["y"]))
        var issues: Array = []
        if not (b.seated and life.my_seat == str(s["id"])):
            issues.append("没坐上（seated %s my_seat %s）" % [b.seated, life.my_seat])
        if b.face != str(s["face"]):
            issues.append("朝向 %s，座位要 %s" % [b.face, s["face"]])
        if (b.pos - seat_pos).length() > 3.0:
            issues.append("位置 %s，座位 %s" % [str(b.pos), str(seat_pos)])
        if absf(b.seat_lift - (float(s["y"]) - float(s["seat_y"]))) > 0.5:
            issues.append("坐姿抬高 %.0f，应该 %.0f" % [b.seat_lift, float(s["y"]) - float(s["seat_y"])])
        if not (ui.seat_btn.visible and ui.seat_btn.text == ui._txt("stand")):
            issues.append("坐下以后按钮不是「起来」（%s %s）" % [ui.seat_btn.visible, ui.seat_btn.text])
        # 点「起来」
        ui.seat_btn.pressed.emit()
        tick(90)
        if b.seated or life.my_seat != "":
            issues.append("点「起来」没站起来")
        if (b.pos - (s["stand"] as Vector2)).length() > 40.0 or not b._free(b.pos):
            issues.append("站起来站在 %s（空地 %s，能站 %s）" % [str(b.pos), str(s["stand"]), b._free(b.pos)])
        tick(2)
        if not (ui.seat_btn.visible and ui.seat_btn.text == ui._txt("sit")):
            issues.append("站起来以后按钮没变回「坐下」")
        # 再坐、推摇杆站起来
        life.sit(s)
        tick(90)
        b.stick = Vector2(0.0, 1.0) if str(s["face"]) != "down" else Vector2(0.0, -1.0)
        tick(30)
        b.stick = Vector2.ZERO
        if b.seated or life.my_seat != "":
            issues.append("坐着推摇杆没站起来")
        if not issues.is_empty():
            bad_sit.append("%s：%s" % [s["id"], "；".join(issues)])
    print("    坐过 %d 个空座位" % n_sit)
    for l in bad_sit:
        print("    ", l)
    check("11 个空座位：走到跟前出「坐下」、坐上去位置朝向对、「起来」站回空地、推摇杆也站起来；4 个 NPC 占着的不能坐", bad_sit.is_empty() and n_sit == 11)

    print("3 点人说话")
    var bad_talk: Array = []
    var data_people: Dictionary = life.data["people"]
    for id in life.people:
        reenter()
        b.reset_to(door)
        var p: Dictionary = life.people[id]
        tap_world((p["head"] as Vector2) + Vector2(0, 20))
        var issues: Array = []
        if life.pending_talk != id and not ui.talk_box.visible:
            issues.append("点他本人没反应（pending %s）" % life.pending_talk)
        run_until_idle(30.0)
        tick(5)
        if not (ui.talk_box.visible and ui.talk_id == id):
            issues.append("没弹对话框（talk_box %s talk_id %s 站在 %s，他的空地 %s）" % [ui.talk_box.visible, ui.talk_id, str(b.pos), str(p["stand"])])
            bad_talk.append("%s：%s" % [id, "；".join(issues)])
            continue
        if ui.name_label.text != str(data_people[id]["title"]):
            issues.append("名字牌 %s 不是 %s" % [ui.name_label.text, data_people[id]["title"]])
        if b.walking_enabled:
            issues.append("说话时还能走")
        var lines: Array = [] if data_people[id].has("dialogue") else data_people[id]["talk"]
        if data_people[id].has("dialogue"):
            # 10/4 起写了 dialogue 的（奶奶）走对话插件 Dialogue Manager（02 E 改这段）：有字、有人物图、身份卡开关，
            # 再一路点下去（有选项点第一个）直到收；台词、分支细的在 test_lounge_dialogue.gd
            for k in 30:
                if ui.line_raw != "":
                    break
                await process_frame
            if ui.line_raw == "" or ui.portrait.texture == null:
                issues.append("插件第一句没出来（%s）" % ui.line_raw)
            ui.card_btn.pressed.emit()
            tick(2)
            if ui.card == null or (ui.card.find_child("full_body", true, false) as TextureRect).texture == null:
                issues.append("身份卡没开或没有全身图")
            ui.close_card()
            tick(2)
            for k in 40:
                if not ui.talk_box.visible:
                    break
                if ui.choices.visible and ui.choices.get_child_count() > 0:
                    (ui.choices.get_child(0) as Button).pressed.emit()
                else:
                    ui.next_line()
                for f in 3:
                    await process_frame
                tick(1)
        for j in lines.size():
            if ui.line_raw != str(lines[j]["text"]):
                issues.append("第 %d 句字不对：%s" % [j + 1, ui.line_raw])
            if ui.portrait.texture == null:
                issues.append("第 %d 句没有人物图" % (j + 1))
            if j == 0:
                # 身份卡开关
                ui.card_btn.pressed.emit()
                tick(2)
                if ui.card == null or (ui.card.find_child("full_body", true, false) as TextureRect).texture == null:
                    issues.append("身份卡没开或没有全身图")
                else:
                    var title_ok := false
                    for ch in ui.card.find_children("*", "Label", true, false):
                        if (ch as Label).text == str(data_people[id]["title"]):
                            title_ok = true
                    if not title_ok:
                        issues.append("身份卡上没有称呼")
                ui.close_card()
                tick(2)
                if ui.card != null or not ui.talk_box.visible:
                    issues.append("关身份卡没回到对话框")
            ui.next_line()
        if ui.talk_box.visible or ui.talk_id != "" or life.talking != "":
            issues.append("说完没收")
        if not b.walking_enabled:
            issues.append("说完不能走")
        if not issues.is_empty():
            bad_talk.append("%s：%s" % [id, "；".join(issues)])
    for l in bad_talk:
        print("    ", l)
    check("4 位 NPC：点他本人 → 走过去 → 对话框（名字牌、人物图、每句话）→ 身份卡开关 → 说完收、能走（%d 位有问题）" % bad_talk.size(), bad_talk.is_empty())
    # 坐在他旁边直接聊
    reenter()
    b.reset_to(door)
    var sofa_m: Dictionary = life.seat_by_id("sofa_m")
    walk(sofa_m["stand"])
    tick(2)
    life.sit(sofa_m)
    tick(90)
    check("坐在北边沙发中间：坐在奶奶、爷爷当中", b.seated and life.my_seat == "sofa_m")
    tick(2)
    check("坐在沙发中间出「跟 XX 聊聊」（%s）" % ui.talk_btn.text, ui.talk_btn.visible and ui.near_id != "")
    ui.talk_btn.pressed.emit()
    tick(3)
    check("点「聊聊」直接弹对话框、人还坐着", ui.talk_box.visible and b.seated)
    ui.close_talk()
    tick(2)
    check("关了对话框能走（人还坐着；推摇杆站起来）", b.walking_enabled)
    b.stand_up()

    print("4 冒泡")
    reenter()
    b.reset_to(door)
    life.frozen = false
    for id in life.bubbles.keys():
        life._hide_bubble(id)
    var f: Font = b.font
    var bad_glyph: Array = []
    var max_per_group := 0
    var seen_who := {}
    var bubbles_out_of_canvas := 0
    var ctrl_block := 0
    var talk_group_stop := true
    var size: Vector2 = Vector2(float(b.cfg["size"][0]), float(b.cfg["size"][1]))
    for i in int(40.0 / DT):
        life.step(DT)
        for g in life.groups:
            var showing := 0
            var seen_ids := {}
            for l in g["lines"]:
                if not seen_ids.has(str(l[0])):
                    seen_ids[str(l[0])] = true
                    if life.bubble_text(str(l[0])) != "":
                        showing += 1
            max_per_group = maxi(max_per_group, showing)
        for id in life.bubbles:
            var bb: Node2D = life.bubbles[id]
            if not is_instance_valid(bb):
                continue
            var txt := str(bb.get_meta("text"))
            if not seen_who.has(id + txt):
                seen_who[id + txt] = true
                for ch in txt:
                    if f != null and not f.has_char(ch.unicode_at(0)):
                        bad_glyph.append("%s「%s」缺字 %s" % [id, txt, ch])
                var gp: Vector2 = bb.global_position
                if gp.x < 40.0 or gp.x > size.x - 40.0 or gp.y < 40.0:
                    bubbles_out_of_canvas += 1
                for c in bb.find_children("*", "Control", true, false):
                    if (c as Control).mouse_filter != Control.MOUSE_FILTER_IGNORE:
                        ctrl_block += 1
    print("    40 秒里冒过 %d 句（%s）" % [seen_who.size(), str(seen_who.keys().slice(0, 4))])
    check("两组都冒过、一组同时最多一个气泡（最多 %d）" % max_per_group, seen_who.size() >= 6 and max_per_group <= 1)
    check("气泡里的字字体都有（缺 %s）" % str(bad_glyph.slice(0, 3)), bad_glyph.is_empty())
    check("气泡都在画布里（%d 个离边 <40）" % bubbles_out_of_canvas, bubbles_out_of_canvas == 0)
    check("气泡上的控件都不吃点击（%d 个会吃）" % ctrl_block, ctrl_block == 0)
    # 气泡底下点地面照样走
    life.show_bubble("lounge_05", "好多人啊")
    var bb2: Node2D = life.bubbles["lounge_05"]
    reenter()
    b.reset_to(Vector2(948, 480))
    tap_world(Vector2(948, 560))
    check("气泡在头顶冒着，点地面照样走（路 %d 段）" % b.path.size(), b.path.size() > 0 or life.pending_talk != "")
    # 说话那一组停：先等「叔叔阿姨」这一组自然冒出一个气泡，再开始说话，气泡要收、再不冒
    for id in life.bubbles.keys():
        life._hide_bubble(id)
    for g in life.groups:
        g["showing"] = false
        g["t"] = 0.0
    var tea_showing := false
    for i in int(20.0 / DT):
        life.step(DT)
        if life.bubble_text("lounge_05") != "" or life.bubble_text("lounge_06") != "":
            tea_showing = true
            break
    life.talking = "lounge_05"
    var sofa_seen := false
    for i in int(12.0 / DT):
        life.step(DT)
        if life.bubble_text("lounge_09") != "" or life.bubble_text("lounge_10") != "":
            sofa_seen = true
    var talk_bubbles := 0
    for id in ["lounge_05", "lounge_06"]:
        if life.bubble_text(id) != "":
            talk_bubbles += 1
    life.talking = ""
    check("先看到叔叔阿姨那组冒泡，开始跟叔叔说话后气泡收了、12 秒里没再冒（%s、%d 个）" % [tea_showing, talk_bubbles], tea_showing and talk_bubbles == 0)
    # 10/4 07 改规矩（03 测第 67 版第三节：对话框开着时别人的气泡从选项按钮底下露出来，01 H 派）：说话期间哪组都不冒，说完再接着冒
    check("说话期间别的一组（奶奶爷爷）也停着不冒", not sofa_seen)
    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
