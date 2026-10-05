extends SceneTree
## 验收：后厅麻将室、化妆间的人活起来（07 10/4，阿鱼「其他房间里的 npc 也要动起来，对话起来，走动起来，灵活起来」）。无界面跑整个 main.gd。
##   1 两间各一份 lounge_life（mahjong.json、makeup.json）：人数对、都接过替身那张图；休息间照旧四位
##   2 冒泡（阿鱼 10/4 新规矩，05 回执「跟新规矩冲突的 4 个测试」：后厅三间同屏最多两个冒泡，两个在冒时别的组等着）：三间一起跑 90 秒，每一帧同时在冒的 ≤ 2 个、每一组 90 秒内至少冒过一句、冒的都是 json 里那几句；气泡不挡操作（点气泡底下的地照样走过去）
##   3 点人对话：每位能说话的，每个选项各走一遍到底——点他 → 走到 approach → 对话框（名字牌是称呼、走插件）→ 挑选项 → 说完收、又能走；
##     坐着的说话不起身不转身（截的那格不变）
##   4 没写台词的点了不理（当点地面走路）；approach 都能站、从进场点走得到
##   5 走动：打牌的妹妹、化妆助理起身挨个去 wander 那几个点、再回原位，坐着的坐回原来那格；一圈不卡（60 秒内回来）
##   6 走到一半点他：停下说话，说完接着走、照样回原位
## 10/4 02 F：化妆间三位搬进单独那间屋（areas["makeup"] 挂的 lounge_life），测他们先切进那块画布；后厅只剩休息间、麻将室两份
## 用法：Godot --headless --path . --script res://tools/test_room_life.gd     最后一行 RESULT PASS 才算过

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
    for i in 6:
        await process_frame
    tick(1)

func home(lf, p: Dictionary) -> void:
    (p["legs"] as Array).clear()
    (p["path"] as Array).clear()
    p["foot"] = p["home"]
    p["mode"] = p["home_mode"]
    p["face"] = p["seat_face"]
    lf._head(p)
    lf._pose(p, 0.0)

func life_by(room: String):
    for lf in b.lives + m.areas["makeup"].lives:
        if lf.room == room:
            return lf
    return null

## 切到这份人所在的画布（化妆间是单独那间屋，别的在后厅）
func go(lf) -> void:
    var cid := "makeup" if lf.room == "makeup" else "backhall"
    if m.state != cid:
        m._show_canvas(cid)
        m._goto(cid)
        await settle()
    lf.c.walking_enabled = true
    m.dialog.visible = false
    tick(2)

## 跟某位说一遍，有选项挑第 pick 个；回 {opened, title, lines, choices, closed}
func talk_once(lf, id: String, pick: int) -> Dictionary:
    var out := {"opened": false, "title": "", "lines": [], "choices": [], "closed": false}
    lf.request_talk(id)
    for i in int(25.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    await settle()
    out["opened"] = ui.talk_box.visible and ui.dm_res != null
    out["title"] = ui.name_label.text
    for k in 12:
        if not ui.talk_box.visible:
            break
        out["lines"].append(ui.line_raw)
        if ui.choices.visible:
            out["choices"] = ui.choices.get_children().map(func(x): return (x as Button).text)
            ui.next_line()   # 有选项时点对话框不往下走
            await settle()
            if ui.line_raw != out["lines"][-1]:
                out["lines"].append("（点对话框走了）")
            (ui.choices.get_child(pick) as Button).pressed.emit()
        else:
            ui.next_line()
        await settle()
    out["closed"] = not ui.talk_box.visible and lf.c.walking_enabled and lf.talking == ""
    return out

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_rl_court.json"
    m.games_save.local_path = "user://test_rl_games.json"
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")
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

    print("1 两间的人")
    check("后厅两份：休息间、麻将室（%s）；化妆间那份在单独那间屋里" % [b.lives.map(func(x): return x.room)], b.lives.size() == 2 and mj != null and mk != null and b.lives[0] == b.lounge and mk.c == m.areas["makeup"])
    check("休息间照旧四位（%d）" % b.lounge.people.size(), b.lounge.people.size() == 4)
    check("麻将室 14 位、化妆间 3 位（%d、%d）" % [mj.people.size(), mk.people.size()], mj.people.size() == 14 and mk.people.size() == 3)
    var adopted := true
    for lf in [mj, mk]:
        for id in lf.people:
            var p: Dictionary = lf.people[id]
            adopted = adopted and p.has("look") and p.get("spr") == lf.c.npc_nodes.get(id)
    check("两间的人都接过了替身那张图（没另画一个）", adopted)

    print("2 冒泡（三间一起、90 秒、同屏最多两个）")
    var seen := {}
    var max_now := 0
    var over_two := 0
    # 同屏最多两个：后厅一屏（休息间 + 麻将室）、化妆间自己一屏，各算各的（化妆间 10/4 起是单独一间屋、单独一屏）
    for set_lives in [m.backhall.lives, m.areas["makeup"].lives]:
        await go(set_lives[0])
        for i in int(90.0 / DT):
            tick(1)
            var now := 0
            for lf in set_lives:
                for id in lf.bubbles:
                    if is_instance_valid(lf.bubbles[id]):
                        now += 1
                    var t: String = lf.bubble_text(id)
                    if t != "":
                        seen[lf.room + "/" + id + "/" + t] = true
            max_now = maxi(max_now, now)
            if now > 2:
                over_two += 1
    check("每一屏一起跑 90 秒（后厅一屏、化妆间一屏）：每一帧同时在冒的最多 %d 个（要 ≤ 2；超过两个的有 %d 帧）" % [max_now, over_two], max_now <= 2 and over_two == 0 and max_now >= 1)
    await go(mj)
    for lf in m.backhall.lives + m.areas["makeup"].lives:
        for g in lf.data["chat"]:
            var got := 0
            for l in g["lines"]:
                if seen.has(lf.room + "/" + str(l[0]) + "/" + str(l[1])):
                    got += 1
            check("%s「%s」组 90 秒冒了 %d 句（json 里 %d 句；要 ≥ 1）" % [lf.room, g["group"], got, g["lines"].size()], got >= 1)
    for k in seen:
        var parts: PackedStringArray = str(k).split("/")
        var lf = life_by(parts[0])
        var hit := false
        for g in lf.data["chat"]:
            for l in g["lines"]:
                hit = hit or (str(l[0]) == parts[1] and str(l[1]) == parts[2])
        if not hit:
            check("冒的话不在 json 里：%s" % k, false)
    # 气泡底下点地：照样走
    mj.frozen = true
    for id in mj.bubbles.keys():
        mj._hide_bubble(id)
    mj.show_bubble("elder_n", "该你了")
    b.reset_to(Vector2(700, 640))
    tick(2)
    var bub: Node2D = mj.bubbles["elder_n"]
    var under: Vector2 = bub.position + Vector2(0, -12)
    var free_under: Vector2 = b.nearest_free(under)
    var scr: Vector2 = b.get_viewport().get_canvas_transform() * free_under
    b.tap(scr)
    tick(1)
    check("点气泡底下那块地（%s）照样走过去，没被气泡、没被大爷拦" % [free_under], not b.path.is_empty() and b.pending_talker == "" and mj.pending_talk == "")
    mj.frozen = false
    b.path.clear()

    print("3 点人对话（每个选项各走一遍）")
    for lf in [mj, mk]:
        await go(lf)
        for id in lf.people:
            if not lf.can_talk(id):
                continue
            var p: Dictionary = lf.people[id]
            # 起身走动的人（妹妹、化妆助理）起身时间是随机的：先放回原位、这段里别起身，测的是在家坐着（站着）说话那段（第 68 版跑全套时撞上过一次）
            home(lf, p)
            p["wait"] = 9999.0
            var reg0: Rect2 = (p["spr"] as Sprite2D).region_rect
            var n_choices := 2
            for pick in n_choices:
                # 走动的人先等他坐（站）回原位再说，测的是在家那段
                lf.c.reset_to(lf.c.SPAWN if lf == mk else Vector2(700, 640))
                tick(2)
                var r: Dictionary = await talk_once(lf, id, pick)
                var ap: Vector2 = lf.approach_of(id)
                check("%s %s 第 %d 支：开了对话框走插件、名字牌「%s」、说了 %d 句 %s、选项 %s、说完收了能走" % [lf.room, id, pick + 1, r["title"], r["lines"].size(), r["lines"], r["choices"]],
                    r["opened"] and str(r["title"]) == str(p["title"]) and (r["choices"] as Array).size() == n_choices and (r["lines"] as Array).size() >= 4 and not (r["lines"] as Array).has("（点对话框走了）") and r["closed"])
                if (p["foot"] as Vector2) == p["home"] and str(p["home_mode"]) == "sit":
                    check("%s 坐着说话没起身没转身" % id, (p["spr"] as Sprite2D).region_rect == reg0)
            # 两支答的不一样
    print("3b 头像跟名字对得上（01 H 10/4：新娘不放任何人物图）")
    for lf in [mj, mk]:
        await go(lf)
        for id in lf.people:
            if not lf.can_talk(id):
                continue
            lf.c.reset_to(lf.c.SPAWN if lf == mk else Vector2(700, 640))
            tick(2)
            lf.request_talk(id)
            for i in int(25.0 / DT):
                tick(1)
                if ui.talk_box.visible:
                    break
            await settle()
            var code := str(lf.people[id]["code"])
            var sd: Dictionary = {}
            for n in lf.c.cfg["npcs"]:
                if str(n["id"]) == id:
                    sd = n.get("standin", {})
            ui.open_card(id)
            var body = ui.card.find_child("full_body", true, false) if ui.card != null else null
            if id == "bride":
                check("新娘：名字牌「%s」、对话框不放头像、身份卡不放图" % ui.name_label.text,
                    ui.name_label.text == "新娘" and code == "" and not ui.portrait.visible and ui.card != null and body == null)
            else:
                check("%s「%s」：头像、身份卡用的就是场景里他那张（%s = 替身 %s）" % [id, ui.name_label.text, code, sd.get("code", "")],
                    code == str(sd.get("code", "")) and ui.portrait.visible and ui.portrait.texture != null and body != null and (body as TextureRect).texture != null)
            ui.close_card()
            ui.close_talk()
            tick(1)
    var words := ""
    for f in ["res://assets/backhall/mahjong.json", "res://assets/backhall/makeup.json"]:
        words += FileAccess.get_file_as_string(f)
    for f in DirAccess.get_files_at("res://assets/backhall/dialogue"):
        if f.ends_with(".dialogue"):
            words += FileAccess.get_file_as_string("res://assets/backhall/dialogue/" + f)
    check("两间的话里没有「手气」「新娘子好乖」（麻将室只留氛围）", not ("手气" in words) and not ("新娘子好乖" in words))

    print("3c 冒泡字大、不互相压")
    await go(mj)
    var probe_lf = b.lounge
    check("气泡字号 %d（原来 15，04 嫌小）" % probe_lf.BUBBLE_FONT, probe_lf.BUBBLE_FONT >= 20)
    for lf in b.lives:
        lf.frozen = true
        for id in lf.bubbles.keys():
            lf._hide_bubble(id)
    # 照常跑：三间八组各自轮着冒，跑 90 秒，每一帧都看三间所有正冒着的气泡叠不叠（妹妹、化妆助理起身走动也在跑）
    for lf in b.lives:
        for id in lf.bubbles.keys():
            lf._hide_bubble(id)
        lf.frozen = false
    mj.people["card_e"]["wait"] = 2.0
    b.reset_to(b.SPAWN)
    var worst: Array = []
    var most := 0
    for f in int(90.0 / DT):
        tick(1)
        var rects: Array = []
        for lf in b.lives:
            for id in lf.bubbles:
                var bb: Node2D = lf.bubbles[id]
                if bb.scale.x >= lf._bubble_scale() * 0.99:   # 刚冒出来变大那一下不算
                    rects.append([lf.room + "/" + id, lf.bubble_rect(bb)])
        most = maxi(most, rects.size())
        for a in rects.size():
            for c2 in range(a + 1, rects.size()):
                if (rects[a][1] as Rect2).intersects(rects[c2][1]):
                    var tag := "%s×%s" % [rects[a][0], rects[c2][0]]
                    if not tag in worst:
                        worst.append(tag)
    check("后厅一屏照常轮着冒 90 秒（最多同时 %d 个，要 ≤ 2），每一帧都不叠（%s）" % [most, worst], worst.is_empty() and most >= 1 and most <= 2)
    for lf in b.lives:
        for id in lf.bubbles.keys():
            lf._hide_bubble(id)
        lf.frozen = false
    # 单独那间化妆间：两组（化妆台前、化妆助理）跑 40 秒，也不叠
    await go(mk)
    mk.c.reset_to(mk.c.SPAWN)
    var worst_mk: Array = []
    var most_mk := 0
    for f in int(40.0 / DT):
        tick(1)
        var rs: Array = []
        for id in mk.bubbles:
            var bb: Node2D = mk.bubbles[id]
            if bb.scale.x >= mk._bubble_scale() * 0.99:
                rs.append([id, mk.bubble_rect(bb)])
        most_mk = maxi(most_mk, rs.size())
        for a in rs.size():
            for c2 in range(a + 1, rs.size()):
                if (rs[a][1] as Rect2).intersects(rs[c2][1]) and not ("%s×%s" % [rs[a][0], rs[c2][0]]) in worst_mk:
                    worst_mk.append("%s×%s" % [rs[a][0], rs[c2][0]])
    check("化妆间两组轮着冒 40 秒（最多同时 %d 个），每一帧都不叠（%s）" % [most_mk, worst_mk], worst_mk.is_empty() and most_mk >= 1)
    for id in mk.bubbles.keys():
        mk._hide_bubble(id)
    await go(mj)

    print("3e 对话框开着时哪间都不冒泡（03 测第 67 版：妹妹的气泡从选项底下露出来）")
    b.reset_to(Vector2(700, 640))
    tick(2)
    mj.request_talk("elder_n")
    for i in int(25.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    await settle()
    var leak := 0
    for i in int(12.0 / DT):
        tick(1)
        for lf in b.lives:
            leak += lf.bubbles.size()
    check("跟大爷说着话的 12 秒里，三间一个气泡都没冒（%d）" % leak, ui.talk_box.visible and leak == 0)
    ui.close_talk()
    var back_on := 0
    for i in int(8.0 / DT):
        tick(1)
        for lf in b.lives:
            back_on += lf.bubbles.size()
    check("说完又接着冒", back_on > 0)

    print("3d 走近出「跟 XX 聊聊」")
    var btn_ok := true
    for pair in [[mj, "elder_s"], [mj, "mj3_e"], [mk, "makeup_1"]]:
        await go(pair[0])
        pair[0].c.reset_to(pair[0].approach_of(pair[1]))
        tick(3)
        var want: String = "跟%s聊聊" % str(pair[0].person(pair[1])["title"])
        print("    ", pair[1], " 按钮 ", ui.talk_btn.visible, " ", ui.talk_btn.text)
        btn_ok = btn_ok and ui.talk_btn.visible and ui.talk_btn.text == want
    ui.talk_btn.pressed.emit()
    for i in int(5.0 / DT):
        tick(1)
        if ui.talk_box.visible:
            break
    await settle()
    check("走到孃孃、姐姐、化妆师跟前出「跟 XX 聊聊」，点了就开聊", btn_ok and ui.talk_box.visible and ui.name_label.text == "化妆师")
    ui.close_talk()
    tick(1)

    print("4 不说话的、站位")
    var silent := true
    for id in ["elder_w", "elder_e", "mj_guest_1", "card_n"]:
        var p: Dictionary = mj.people[id]
        silent = silent and mj.npc_at((p["foot"] as Vector2) + Vector2(0, -20)) == "" and not mj.can_talk(id)
    check("没写台词的（elder_w 等）点了不理", silent)
    var ap_ok := true
    for lf in [mj, mk]:
        for id in lf.people:
            if lf.can_talk(id):
                var ap: Vector2 = lf.approach_of(id)
                var reach: bool = lf.c._free(ap) and not lf.c.find_path(lf.c.SPAWN, ap).is_empty()
                if not reach:
                    print("    站不了：", id, ap)
                ap_ok = ap_ok and reach
    check("能说话的每位，玩家站的位置能站、从进场点走得到", ap_ok)

    print("5 走动")
    for pair in [[mj, "card_e"], [mk, "makeup_2"]]:
        var lf = pair[0]
        var id: String = pair[1]
        var p: Dictionary = lf.people[id]
        # 前面说话时他可能正走到一半：先放回原位（坐着的坐好）再从头走一圈
        await go(lf)
        home(lf, p)
        var reg0: Rect2 = (p["spr"] as Sprite2D).region_rect
        var spots: Array = p["spots"]
        lf.c.reset_to(lf.c.SPAWN)
        tick(2)
        p["wait"] = 0.0
        var visited := {}
        var left_home := false
        var back := false
        var walked_frames := {}
        var stuck := 0.0
        var last: Vector2 = p["foot"]
        for i in int(60.0 / DT):
            tick(1)
            var f: Vector2 = p["foot"]
            if f != p["home"]:
                left_home = true
            for k in spots.size():
                if f.distance_to(spots[k]) < 1.0:
                    visited[k] = true
            if str(p["mode"]) == "walk":
                walked_frames[(p["spr"] as Sprite2D).region_rect.position.x] = true
                stuck = stuck + DT if f.distance_to(last) < 0.01 else 0.0
            last = f
            if left_home and f == p["home"] and str(p["mode"]) == str(p["home_mode"]):
                back = true
                break
        check("%s 起身走了、%d 个点都到了（%s）、60 秒内回原位、%s" % [id, spots.size(), visited.keys(), p["home_mode"]], left_home and visited.size() == spots.size() and back)
        check("%s 走路换了走路格（%d 种）、没原地卡住" % [id, walked_frames.size()], walked_frames.size() >= 3 and stuck < 1.0)
        check("%s 回来那格跟走之前一样" % id, (p["spr"] as Sprite2D).region_rect == reg0)

    print("6 走到一半点他")
    var p2: Dictionary = mk.people["makeup_2"]
    await go(mk)
    home(mk, p2)
    mk.c.reset_to(mk.c.SPAWN)
    tick(2)
    p2["wait"] = 0.0
    for i in int(30.0 / DT):
        tick(1)
        if str(p2["mode"]) == "walk" and (p2["foot"] as Vector2).distance_to(p2["home"]) > 60.0:
            break
    var mid: Vector2 = p2["foot"]
    var r2: Dictionary = await talk_once(mk, "makeup_2", 0)
    check("走到一半（%s）点化妆助理：停下说完" % [mid], r2["opened"] and r2["closed"] and (p2["foot"] as Vector2).distance_to(mid) < 40.0)
    var home_again := false
    for i in int(60.0 / DT):
        tick(1)
        if p2["foot"] == p2["home"] and str(p2["mode"]) == "idle" and (p2["legs"] as Array).is_empty() and (p2["path"] as Array).is_empty():
            home_again = true
            break
    check("说完接着走、回了原位", home_again)

    print("RESULT ", "PASS" if ok else "FAIL")
    quit()
