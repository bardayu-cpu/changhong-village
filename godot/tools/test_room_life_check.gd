extends SceneTree
## 第 67 版麻将室、化妆间的人活起来（07 做），03 自己重测（01 H 10/4 派，不改游戏代码；不用 07 的 test_room_life 里的 talk_once，另起量法）：
##   1 7 位能说话的：真点他（按他头那一点的屏幕坐标点）→ 走到跟前 → 对话框；**期望的句子、选项、回话都从 .dialogue 文件里自己解析出来**，
##     实际显示的逐句对：开头几句、选项文字、挑每个选项后他回的话、最后一句；名字牌 = 人员表里的称呼；说完收、能走；坐着的说话那一格没变
##   2 没写台词的（点了不理）：点他当点地面走路，不开对话框
##   3 走一圈的两位（麻将室打牌的妹妹、化妆间助理）各跑两遍 120 秒：A 玩家站远处；B 玩家一直站在他第一个要去的站点上。
##     每遍：起身 → 每个站点都到 → 回原位用不到 60 秒；原地卡住（走路时一格不动）不超过 10 秒；他站着或走着的脚点从不落在后厅四个门洞（前沿矮墙留的口）里；
##     玩家站着不动他也走得完；走完玩家照样走得动
##   4 冒泡：手机 540×960 和长屏 585×1266 各跑 60 秒、每半秒量一次，所有在冒的气泡（换成屏幕坐标）整个在屏里；
##     对话框开着（有选项）时，气泡不压对话框、名字牌、选项按钮；站在人跟前出「聊聊」按钮时，气泡不压按钮
## 用法：Godot --headless --path . --script res://tools/test_room_life_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 30.0

var m
var started := false
var ok := true
var b
var ui

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

func settle() -> void:
    await frames(6)
    tick(1)

func life_by(room: String):
    for lf in b.lives:
        if lf.room == room:
            return lf
    return null

## 把 .dialogue 文件解析成：{pre: [句], options: [{text, reply: [句]}], post: [句]}（只认这套写法：「谁: [#tag] 话」「- 选项」缩进回话、=> END）
func parse_dialogue(path: String) -> Dictionary:
    var out := {"pre": [], "options": [], "post": []}
    var cur_opt := -1
    for raw in FileAccess.get_file_as_string(path).split("\n"):
        var ln: String = raw.strip_edges(false, true)
        if ln.strip_edges() == "" or ln.begins_with("#") or ln.begins_with("~") or ln.begins_with("=>"):
            continue
        if ln.begins_with("- "):
            (out["options"] as Array).append({"text": ln.substr(2).strip_edges(), "reply": []})
            cur_opt = (out["options"] as Array).size() - 1
            continue
        var is_indented := raw.begins_with("\t") or raw.begins_with("  ")
        var body: String = ln.strip_edges()
        var at := body.find(": ")
        if at < 0:
            continue
        var text := body.substr(at + 2)
        while text.begins_with("[#"):
            text = text.substr(text.find("]") + 1).strip_edges()
        if is_indented and cur_opt >= 0:
            ((out["options"] as Array)[cur_opt]["reply"] as Array).append(text)
        elif (out["options"] as Array).is_empty():
            (out["pre"] as Array).append(text)
        else:
            (out["post"] as Array).append(text)
            cur_opt = -1
    return out

## 屏幕坐标（窗口像素）：世界点 → 子视口 → 窗口
func to_screen(wp: Vector2) -> Vector2:
    var sv: SubViewport = m.view.get_child(0)
    var cc: Vector2 = b.cam.get_screen_center_position()
    var z: float = b.cam.zoom.x
    var in_sv := (wp - cc) * z + Vector2(sv.size) * 0.5
    return in_sv * (Vector2(get_root().size) / Vector2(sv.size))

func bubble_rects(lf) -> Array:
    var out: Array = []
    for id in lf.bubbles:
        var hs: Vector2 = to_screen((lf.people[id]["head"] as Vector2))
        if hs.x < 60.0 or hs.x > float(get_root().size.x) - 60.0 or hs.y < 60.0 or hs.y > float(get_root().size.y) - 60.0:
            continue   # 说话的人自己在屏幕边上（或屏幕外）：气泡露一半是正常的，只量人在屏里、离边 60 像素以上的
        var bn: Node2D = lf.bubbles[id]
        if not is_instance_valid(bn) or not bn.visible:
            continue
        var box: Panel = bn.get_child(0)
        var a: Vector2 = bn.position + box.position * bn.scale
        var z: Vector2 = bn.position + (box.position + box.size) * bn.scale
        var sa: Vector2 = to_screen(a)
        var sb: Vector2 = to_screen(z)
        out.append([id, Rect2(sa, sb - sa)])
    return out

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_rlcheck_court.json"
    m.games_save.local_path = "user://test_rlcheck_games.json"
    m.ensure_canvas("backhall")
    m._show_canvas("backhall")
    m._goto("backhall")
    await process_frame
    b = m.backhall
    b.walking_enabled = true
    m.dialog.visible = false
    ui = m.lounge_ui
    tick(2)
    ui.attach(b.lounge)
    var mj = life_by("mahjong")
    var mk = life_by("makeup")

    print("1 七位的对话，期望的句子从 .dialogue 文件自己解析")
    var talkers: Array = []
    for lf in [mj, mk]:
        for id in lf.people:
            if lf.can_talk(id):
                talkers.append([lf, id])
    check("能说话的 7 位（麻将室 4 + 化妆间 3）：%d" % talkers.size(), talkers.size() == 7)
    var bad: Array = []
    var runs := 0
    for pr in talkers:
        var lf = pr[0]
        var id: String = pr[1]
        var p: Dictionary = lf.people[id]
        var dlg_path: String = str(lf.data["people"][id]["dialogue"])
        var pack_mode: bool = not FileAccess.file_exists(dlg_path)   # 导出包里 .dialogue 原文件读不到（只有导入好的资源）：只量结构，不对字
        var want: Dictionary = parse_dialogue(dlg_path) if not pack_mode else {"pre": ["", ""], "options": [{"text": "", "reply": [""]}, {"text": "", "reply": [""]}], "post": [""]}
        var n_opt: int = (want["options"] as Array).size()
        if n_opt != 2 or (want["pre"] as Array).size() < 2 or (want["post"] as Array).is_empty():
            bad.append("%s 的 .dialogue 解析出来不是「几句 + 二选一 + 收尾」：%s" % [id, str(want)])
            continue
        for pick in n_opt:
            # 走动的先放回原位（坐着的坐好）
            (p["legs"] as Array).clear()
            (p["path"] as Array).clear()
            p["foot"] = p["home"]
            p["mode"] = p["home_mode"]
            p["face"] = p["seat_face"]
            lf._head(p)
            lf._pose(p, 0.0)
            var reg0: Rect2 = (p["spr"] as Sprite2D).region_rect   # 放回原位摆好以后那一格
            b.reset_to(b.SPAWN if lf == mk else Vector2(700, 640))
            tick(2)
            if ui.is_open():
                ui.hide_all()
            b.walking_enabled = true
            # 真点：按他头往下 20 像素那一点的屏幕坐标点
            var head: Vector2 = p["head"]
            b.tap(b.get_viewport().get_canvas_transform() * (head + Vector2(0, 20)))
            for i in int(30.0 / DT):
                tick(1)
                if ui.talk_box.visible:
                    break
            await settle()
            runs += 1
            if not ui.talk_box.visible:
                bad.append("%s 第 %d 支：点了没开对话框（人在 %s，要去 %s）" % [id, pick + 1, str(b.pos), str(lf.approach_of(id))])
                continue
            var seen: Array = []
            var names: Array = []
            var opts: Array = []
            var portrait_ok := true
            for k in 14:
                if not ui.talk_box.visible:
                    break
                seen.append(str(ui.line_label.text))
                names.append(str(ui.name_label.text))
                portrait_ok = portrait_ok and ui.portrait.texture != null
                if ui.choices.visible:
                    opts = ui.choices.get_children().filter(func(x): return not x.is_queued_for_deletion()).map(func(x): return (x as Button).text)
                    (ui.choices.get_child(pick) as Button).pressed.emit()
                else:
                    ui.next_line()
                await settle()
            var expect: Array = (want["pre"] as Array).duplicate()
            expect.append_array((want["options"] as Array)[pick]["reply"])
            expect.append_array(want["post"])
            # 选项出现那一刻对话框上显示的是「选项前最后一句」，所以 seen 里该句只出现一次（点选项后直接是回话）
            var opt_texts: Array = (want["options"] as Array).map(func(o): return o["text"])
            var err := ""
            if pack_mode:
                if seen.size() < 4 or opts.size() != 2 or seen.any(func(x): return str(x) == ""):
                    err += "（包内只量结构）句数 %d（要 ≥ 4）或选项 %d 个（要 2）或有空句；" % [seen.size(), opts.size()]
            else:
                if seen != expect:
                    err += "实际 %s ≠ 期望 %s；" % [str(seen), str(expect)]
                if opts != opt_texts:
                    err += "选项 %s ≠ %s；" % [str(opts), str(opt_texts)]
            if names.any(func(x): return x != str(p["title"])):
                err += "名字牌 %s ≠ 称呼「%s」；" % [str(names), str(p["title"])]
            if not portrait_ok:
                err += "有一句没人物图；"
            if ui.talk_box.visible or not b.walking_enabled or lf.talking != "":
                err += "说完没收好；"
            if (p["foot"] as Vector2) == p["home"] and str(p["home_mode"]) == "sit" and (p["spr"] as Sprite2D).region_rect != reg0:
                err += "坐着说话换了格（起身或转身了）；"
            if err != "":
                bad.append("%s 第 %d 支：%s" % [id, pick + 1, err])
    for x in bad:
        print("    ", x)
    check("7 位 × 2 支 = %d 遍：句子、选项、回话跟 .dialogue 一字不差、名字牌对、说完收（%d 处不对）" % [runs, bad.size()], bad.is_empty() and runs == 14)

    print("2 不写台词的，点了不理")
    var silent_bad: Array = []
    for pr in [[mj, "elder_w"], [mj, "elder_e"], [mj, "card_n"], [mj, "mj_guest_1"]]:
        var lf = pr[0]
        var id: String = pr[1]
        if not lf.people.has(id):
            silent_bad.append("%s 不存在" % id)
            continue
        var p: Dictionary = lf.people[id]
        b.reset_to(Vector2(700, 640))
        tick(2)
        if ui.is_open():
            ui.hide_all()
        b.walking_enabled = true
        b.path.clear()
        b.tap(b.get_viewport().get_canvas_transform() * ((p["head"] as Vector2) + Vector2(0, 20)))
        tick(3)
        if ui.talk_box.visible or lf.pending_talk != "":
            silent_bad.append("%s 点了开了对话（或排了要走去说）" % id)
        b.path.clear()
    check("4 位没写台词的：点了没开对话框、没排「走去说话」（%d 处不对 %s）" % [silent_bad.size(), str(silent_bad)], silent_bad.is_empty())

    print("3 走一圈的两位")
    var gaps: Array = []
    var fronts: Array = []
    for it in b.cfg["items"]:
        if str(it.get("id", "")).begins_with("front_") and it.has("rect"):
            fronts.append(it["rect"])
    fronts.sort_custom(func(x, y): return float(x[0]) < float(y[0]))
    for i in range(fronts.size() - 1):
        var x0 := float(fronts[i][2])
        var x1 := float(fronts[i + 1][0])
        if x1 - x0 >= 60.0:
            gaps.append(Rect2(x0, float(fronts[i][1]) - 20.0, x1 - x0, 60.0))
    print("    后厅前沿矮墙留的门洞：%s" % str(gaps))
    check("找到 4 个门洞（后厨、麻将室、休息室、化妆间）", gaps.size() == 4)
    for pair in [[mj, "card_e"], [mk, "makeup_2"]]:
        var lf = pair[0]
        var id: String = pair[1]
        var p: Dictionary = lf.people[id]
        var spots: Array = p["spots"]
        for mode in ["A 玩家站远处", "B 玩家站在第一个站点上"]:
            (p["legs"] as Array).clear()
            (p["path"] as Array).clear()
            p["foot"] = p["home"]
            p["mode"] = p["home_mode"]
            p["face"] = p["seat_face"]
            lf._head(p)
            lf._pose(p, 0.0)
            if ui.is_open():
                ui.hide_all()
            b.walking_enabled = true
            b.reset_to(b.SPAWN if mode.begins_with("A") else b.nearest_free(spots[0]))
            tick(2)
            p["wait"] = 0.0
            var visited := {}
            var left_home := false
            var t_left := -1.0
            var t_back := -1.0
            var stuck := 0.0
            var max_stuck := 0.0
            var in_gap := 0
            var last: Vector2 = p["foot"]
            var t := 0.0
            for i in int(120.0 / DT):
                tick(1)
                t += DT
                var f: Vector2 = p["foot"]
                if f != p["home"] and not left_home:
                    left_home = true
                    t_left = t
                for k in spots.size():
                    if f.distance_to(spots[k]) < 1.0:
                        visited[k] = true
                for g in gaps:
                    if (g as Rect2).has_point(f):
                        in_gap += 1
                if str(p["mode"]) == "walk":
                    stuck = stuck + DT if f.distance_to(last) < 0.01 else 0.0
                    max_stuck = maxf(max_stuck, stuck)
                else:
                    stuck = 0.0
                last = f
                if left_home and t_back < 0.0 and f == p["home"] and str(p["mode"]) == str(p["home_mode"]) and (p["legs"] as Array).is_empty():
                    t_back = t
                    break
            var took: float = (t_back - t_left) if t_back > 0.0 and t_left >= 0.0 else -1.0
            # 玩家照样走得动
            b.stick = Vector2(0, 1)
            var p0: Vector2 = b.pos
            tick(20)
            b.stick = Vector2.ZERO
            var moved: float = b.pos.distance_to(p0)
            check("%s（%s）：起身 %.0f 秒时走的，%d 个站点到了 %d 个，回原位用 %.0f 秒，走路时最长一格不动 %.1f 秒，落在门洞里 %d 帧，玩家还能走（%.0f 像素）" % [id, mode, t_left, spots.size(), visited.size(), took, max_stuck, in_gap, moved],
                left_home and visited.size() == spots.size() and took > 0.0 and took < 60.0 and max_stuck < 10.0 and in_gap == 0 and moved > 5.0)

    print("4 冒泡不压东西（手机、长屏）")
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        var screen := Rect2(Vector2.ZERO, Vector2(sz))
        var out_of: Array = []
        var over_dialog: Array = []
        var over_btn: Array = []
        var n_bub := 0
        for lf_room in ["mahjong", "makeup"]:
            var lf = life_by(lf_room)
            # 站在人跟前（出「聊聊」按钮）+ 开着有选项的对话框，各量一阵
            for stage in ["聊聊按钮", "对话框选项"]:
                if ui.is_open():
                    ui.hide_all()
                b.walking_enabled = true
                var tid: String = "elder_n" if lf_room == "mahjong" else "bride"
                var tp: Dictionary = lf.people[tid]
                b.reset_to(b.nearest_free(lf.approach_of(tid)))
                b.cam.reset_smoothing()
                tick(3)
                await frames(2)
                if stage == "对话框选项":
                    lf.request_talk(tid)
                    for i in 10:
                        tick(1)
                    await settle()
                    for k in 3:
                        if ui.talk_box.visible and not ui.choices.visible:
                            ui.next_line()
                            await settle()
                for i in int(60.0 / 0.5):
                    for j in 15:
                        tick(1)   # 0.5 秒
                    await frames(1)
                    for pr in [["mahjong", life_by("mahjong")], ["makeup", life_by("makeup")]]:
                        for rb in bubble_rects(pr[1]):
                            n_bub += 1
                            var r: Rect2 = rb[1]
                            if not screen.encloses(r):
                                out_of.append("%s %s 气泡 %s 出屏" % [sz, rb[0], str(r)])
                            if stage == "对话框选项" and ui.talk_box.visible:
                                if r.intersects(ui.talk_box.get_global_rect()):
                                    over_dialog.append("%s 压对话框" % rb[0])
                                if r.intersects(ui.name_plate.get_global_rect()):
                                    over_dialog.append("%s 压名字牌" % rb[0])
                                if ui.choices.visible:
                                    for ch in ui.choices.get_children():
                                        if not ch.is_queued_for_deletion() and r.intersects((ch as Button).get_global_rect()):
                                            over_btn.append("%s 压选项「%s」" % [rb[0], (ch as Button).text])
                            if stage == "聊聊按钮" and ui.talk_btn.visible and r.intersects(ui.talk_btn.get_global_rect()):
                                over_btn.append("%s 压「聊聊」按钮" % rb[0])
                if ui.is_open():
                    ui.hide_all()
        print("    %dx%d：量了 %d 个气泡样本；出屏 %d、压对话框 %d、压按钮 %d" % [sz.x, sz.y, n_bub, out_of.size(), over_dialog.size(), over_btn.size()])
        for x in (out_of + over_dialog + over_btn).slice(0, 6):
            print("      ", x)
        var known_btn := over_btn.filter(func(x): return str(x).begins_with("card_e 压选项「会一点」"))
        var other_btn := over_btn.filter(func(x): return not str(x).begins_with("card_e 压选项「会一点」"))
        check("%dx%d：气泡（说话的人在屏里的）整个在屏里（%d 处出屏）、不压对话框、名字牌（%d 处）、不压聊聊按钮和别的选项（%d 处）；已知：对大爷说话、选项开着时，打牌妹妹的气泡会从「会一点」底下露出来（这次 %d 个样本，每次跑 0～5 个，只守不超过 8）" % [sz.x, sz.y, out_of.size(), over_dialog.size(), other_btn.size(), known_btn.size()],
            n_bub >= 40 and out_of.is_empty() and over_dialog.is_empty() and other_btn.is_empty() and known_btn.size() <= 8)   # 第 67 版现状；07 把冒泡字调大后要重量
    get_root().size = Vector2i(540, 960)

    DirAccess.remove_absolute("user://test_rlcheck_court.json")
    DirAccess.remove_absolute("user://test_rlcheck_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
