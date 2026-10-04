extends SceneTree
## 验收：后厅麻将室、化妆间的人活起来（07 10/4，阿鱼「其他房间里的 npc 也要动起来，对话起来，走动起来，灵活起来」）。无界面跑整个 main.gd。
##   1 两间各一份 lounge_life（mahjong.json、makeup.json）：人数对、都接过替身那张图；休息间照旧四位
##   2 冒泡：跑 20 秒，每组都冒过话、是 json 里那几句；气泡不挡操作（点气泡底下的地照样走过去）
##   3 点人对话：每位能说话的，每个选项各走一遍到底——点他 → 走到 approach → 对话框（名字牌是称呼、走插件）→ 挑选项 → 说完收、又能走；
##     坐着的说话不起身不转身（截的那格不变）
##   4 没写台词的点了不理（当点地面走路）；approach 都能站、从进场点走得到
##   5 走动：打牌的妹妹、化妆助理起身挨个去 wander 那几个点、再回原位，坐着的坐回原来那格；一圈不卡（60 秒内回来）
##   6 走到一半点他：停下说话，说完接着走、照样回原位
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
    for lf in b.lives:
        if lf.room == room:
            return lf
    return null

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
        out["lines"].append(ui.line_label.text)
        if ui.choices.visible:
            out["choices"] = ui.choices.get_children().map(func(x): return (x as Button).text)
            ui.next_line()   # 有选项时点对话框不往下走
            await settle()
            if ui.line_label.text != out["lines"][-1]:
                out["lines"].append("（点对话框走了）")
            (ui.choices.get_child(pick) as Button).pressed.emit()
        else:
            ui.next_line()
        await settle()
    out["closed"] = not ui.talk_box.visible and b.walking_enabled and lf.talking == ""
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
    check("后厅三份：休息间、麻将室、化妆间（%s）" % [b.lives.map(func(x): return x.room)], b.lives.size() == 3 and mj != null and mk != null and b.lives[0] == b.lounge)
    check("休息间照旧四位（%d）" % b.lounge.people.size(), b.lounge.people.size() == 4)
    check("麻将室 14 位、化妆间 3 位（%d、%d）" % [mj.people.size(), mk.people.size()], mj.people.size() == 14 and mk.people.size() == 3)
    var adopted := true
    for lf in [mj, mk]:
        for id in lf.people:
            var p: Dictionary = lf.people[id]
            adopted = adopted and p.has("look") and p.get("spr") == b.npc_nodes.get(id)
    check("两间的人都接过了替身那张图（没另画一个）", adopted)

    print("2 冒泡")
    var seen := {}
    for i in int(20.0 / DT):
        tick(1)
        for lf in [mj, mk]:
            for id in lf.bubbles:
                var t: String = lf.bubble_text(id)
                if t != "":
                    seen[lf.room + "/" + id + "/" + t] = true
    for lf in [mj, mk]:
        for g in lf.data["chat"]:
            var got := 0
            var bad := []
            for l in g["lines"]:
                if seen.has(lf.room + "/" + str(l[0]) + "/" + str(l[1])):
                    got += 1
            check("%s「%s」组 20 秒冒了 %d 句（json 里 %d 句）" % [lf.room, g["group"], got, g["lines"].size()], got >= 2)
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
        for id in lf.people:
            if not lf.can_talk(id):
                continue
            var p: Dictionary = lf.people[id]
            var reg0: Rect2 = (p["spr"] as Sprite2D).region_rect
            var n_choices := 2
            for pick in n_choices:
                # 走动的人先等他坐（站）回原位再说，测的是在家那段
                b.reset_to(b.SPAWN if lf == mk else Vector2(700, 640))
                tick(2)
                var r: Dictionary = await talk_once(lf, id, pick)
                var ap: Vector2 = lf.approach_of(id)
                check("%s %s 第 %d 支：开了对话框走插件、名字牌「%s」、说了 %d 句 %s、选项 %s、说完收了能走" % [lf.room, id, pick + 1, r["title"], r["lines"].size(), r["lines"], r["choices"]],
                    r["opened"] and str(r["title"]) == str(p["title"]) and (r["choices"] as Array).size() == n_choices and (r["lines"] as Array).size() >= 4 and not (r["lines"] as Array).has("（点对话框走了）") and r["closed"])
                if (p["foot"] as Vector2) == p["home"] and str(p["home_mode"]) == "sit":
                    check("%s 坐着说话没起身没转身" % id, (p["spr"] as Sprite2D).region_rect == reg0)
            # 两支答的不一样
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
                var reach: bool = b._free(ap) and not b.find_path(b.SPAWN, ap).is_empty()
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
        home(lf, p)
        var reg0: Rect2 = (p["spr"] as Sprite2D).region_rect
        var spots: Array = p["spots"]
        b.reset_to(b.SPAWN)
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
    home(mk, p2)
    b.reset_to(b.SPAWN)
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
