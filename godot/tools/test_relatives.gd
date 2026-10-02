extends SceneTree
## 验收：55 桌大厅的亲友 NPC（01 D 9/29，照 docs/宴会厅-亲友NPC-玩家说明.md）
## 0 第 44 版厅没有亲友；1 18 位、称呼和关系照那页原话、【待讨论】的关系空着、没有男方父母公婆亲家；
## 2 北京时间：12～14、17～19 点开席（前闭后开），不看手机时区；
## 3 开席前：走动、站着说话、找熟人，不占座；一路上不穿桌不卡墙（每一步都在能走的格子上），停下来不在红毯上；
## 4 开席：坐回 T9、T11、T7（不占 T1～T6），有人去主桌敬酒再回来，T11 打牌桌上有牌；
## 5 称呼：走着的一直挂，坐下了只亮跟前那位；6 走到跟前冒「看看 XX」，点开身份卡（称呼 + 关系；待讨论的只有称呼）；
## 7 真人坐了亲友的椅子，亲友换一把；8 调试开关三档；9 切回第 44 版没有亲友
## 用法：Godot --headless --path . --script res://tools/test_relatives.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Relatives = preload("res://scripts/relatives.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))
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

func frames(n: int) -> void:
    for i in n:
        await process_frame

## 手动快进亲友：secs 秒，每步 0.05；每一步都看走着的人在不在能走的格子上、停着的在不在红毯上
func sim(rel, secs: float, stats: Dictionary) -> void:
    var h = m.hall
    for i in int(secs / 0.05):
        rel._process(0.05)
        for r in rel.rels:
            stats[r.state] = int(stats.get(r.state, 0)) + 1
            if r.state in ["walk", "seek", "go_seat", "back", "go_toast", "idle", "chat", "toast", "stand"]:
                if not h._free(r.pos):
                    stats["bad_free"] = int(stats.get("bad_free", 0)) + 1
                    if not stats.has("bad_free_at"):
                        stats["bad_free_at"] = "%s %s %s" % [r.title, r.state, r.pos]
            if r.state in ["idle", "chat"] and r.pos.x > rel.carpet.x and r.pos.x < rel.carpet.y:
                stats["on_carpet"] = int(stats.get("on_carpet", 0)) + 1
                if not stats.has("on_carpet_at"):
                    stats["on_carpet_at"] = "%s %s" % [r.title, r.pos]

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true

    print("0 第 44 版厅没有亲友")
    await m._set_hall55(false)   # 第 52 版起默认 55 桌，先切到第 44 版（开关文件最后删掉）
    await m._enter_banquet()
    await create_timer(0.5).timeout
    check("第 44 版厅：没有亲友", m.hall.life.relatives == null and not m.rel_btn.visible)

    print("1 55 桌厅：18 位亲友")
    await m._set_hall55(true)
    await create_timer(0.8).timeout
    var h = m.hall
    var rel = h.life.relatives
    check("有亲友：%d 位" % (rel.rels.size() if rel != null else 0), rel != null and rel.rels.size() == 18)
    var want := {"大爸": "爸爸的大哥", "大娘": "大哥的爱人", "小虎哥": "大爸的大儿子", "大嫂": "小虎哥的爱人",
        "二爸": "爸爸的二哥", "二娘": "二哥的爱人", "二孃": "妈妈的堂姐",
        "四孃": "", "四姑爷": "", "六孃": "", "六姑爷": "", "小舅": "", "小舅妈": "",
        "周叔": "阿鱼爸爸最好的朋友", "李叔": "阿鱼爸爸最好的朋友", "丹孃": "周叔的爱人",
        "小江": "阿鱼初中起的好朋友，男生，现在最熟的老朋友", "表弟媳": "阿鱼表弟的媳妇，有两个女儿"}
    var bad: Array = []
    for r in rel.rels:
        if not want.has(r.title) or want[r.title] != r.relation:
            bad.append(r.title)
    check("称呼、关系照那页原话，待讨论的空着（对不上的 %s）" % [bad], bad.is_empty())
    var words := ""
    for r in rel.rels:
        words += r.title + r.relation
    check("没有男方父母、公婆、亲家", not (words.contains("公婆") or words.contains("亲家") or words.contains("男方") or words.contains("婆婆") or words.contains("公公")))
    # 长相按称呼分男女（04 9/29）
    var pools: Dictionary = h.life.look_pools()
    var male := ["大爸", "小虎哥", "二爸", "四姑爷", "六姑爷", "小舅", "周叔", "李叔", "小江"]
    var wrong_sex: Array = []
    for r in rel.rels:
        var pool: Array = pools["m"] if r.title in male else pools["f"]
        if not pool.has(r.row):
            wrong_sex.append(r.title)
    check("长相按称呼分男女（男 %d 种、女 %d 种可挑；挑错的 %s）" % [pools["m"].size(), pools["f"].size(), wrong_sex], wrong_sex.is_empty() and pools["m"].size() >= 3)
    var dad_look: Dictionary = load("res://scripts/sprites.gd").guest_look(rel.find("大爸").row)
    check("大爸：%s 头发、金耳环 %s" % [dad_look["hair"], str(dad_look["pal"]["g"]) == "#D4AF37"], dad_look["hair"] in ["short", "bald"] and str(dad_look["pal"]["g"]) != "#D4AF37")
    var tabs := {}
    for r in rel.rels:
        tabs[r.table] = true
    var game_tabs := false
    for tid in tabs:
        if tid in ["T1", "T2", "T3", "T4", "T5", "T6"]:
            game_tabs = true
    check("开席坐的桌 %s，不占 T1～T6 游戏桌" % [tabs.keys()], not game_tabs and tabs.has("T9") and tabs.has("T11") and tabs.has("T7"))

    print("2 北京时间")
    # 2026-09-29 04:30 UTC = 北京 12:30
    var base := 1790640000.0   # 2026-09-29 00:00 UTC
    check("UTC 04:30 = 北京 12.5 点", absf(Relatives.beijing_hour(base + 4.5 * 3600.0) - 12.5) < 0.001)
    var win: Array = rel.conf["feast"]
    check("北京 11:59 不开席、12:00 开席、13:59 开席、14:00 不开席",
        not Relatives.in_feast(11.99, win) and Relatives.in_feast(12.0, win) and Relatives.in_feast(13.99, win) and not Relatives.in_feast(14.0, win))
    check("北京 17:00～18:59 开席、19:00 不开席、半夜不开席",
        Relatives.in_feast(17.0, win) and Relatives.in_feast(18.5, win) and not Relatives.in_feast(19.0, win) and not Relatives.in_feast(2.0, win))
    check("UTC 16:30（北京第二天 0:30）不开席；UTC 09:30（北京 17:30）开席",
        not Relatives.in_feast(Relatives.beijing_hour(base + 16.5 * 3600.0), win) and Relatives.in_feast(Relatives.beijing_hour(base + 9.5 * 3600.0), win))
    rel.unix_override = base + 9.5 * 3600.0
    rel.force = ""
    check("按北京时间：UTC 09:30 当开席", rel._feast_now())
    rel.unix_override = base + 1.0 * 3600.0
    check("UTC 01:00（北京 9 点）当开席前", not rel._feast_now())
    rel.unix_override = -1.0

    print("3 开席前：走动、说话、不占座")
    rel.set_force("pre")
    var st := {}
    await sim(rel, 90.0, st)
    check("没人坐下（%d 次坐着）" % int(st.get("sit", 0)), int(st.get("sit", 0)) == 0)
    check("有人在走（%d）、有人去找熟人（%d）、有人站着说话（%d）" % [int(st.get("walk", 0)), int(st.get("seek", 0)), int(st.get("chat", 0))],
        int(st.get("walk", 0)) > 0 and int(st.get("seek", 0)) > 0 and int(st.get("chat", 0)) > 0)
    check("一路上每一步都在能走的格子上（不穿桌、不卡墙）：出格 %d 次 %s" % [int(st.get("bad_free", 0)), st.get("bad_free_at", "")], int(st.get("bad_free", 0)) == 0)
    check("停下来、说话都不在红毯上：%d 次 %s" % [int(st.get("on_carpet", 0)), st.get("on_carpet_at", "")], int(st.get("on_carpet", 0)) == 0)
    var chairs_empty := true
    for r in rel.rels:
        if r.chair > 0 and h.life.npc_taken.has("%s:%d" % [r.table, r.chair]):
            chairs_empty = false
    check("亲友的椅子上没有随机宾客（开席前空着）", chairs_empty)
    var tagged := 0
    var named := 0
    var on_screen := 0
    var vs: Vector2 = m.get_viewport().get_visible_rect().size / h.cam.zoom.x
    var view := Rect2(h.cam.get_screen_center_position() - vs * 0.5, vs).grow(-40.0)
    for r in rel.rels:
        if r.tag != null and r.tag.text == r.title:
            named += 1
            if view.has_point(r.pos):
                on_screen += 1
                if r.tag.visible:
                    tagged += 1
    check("18 位都有称呼牌（%d）；屏幕里的 %d 位挂着 %d 块（屏幕外的不挂，挤成一团的先收一块）" % [named, on_screen, tagged],
        named == 18 and tagged >= on_screen - 2 and (on_screen == 0 or tagged > 0))
    # 称呼牌不叠：模拟过程中每一步都查太费，这里再走 30 秒、每秒看一次
    var overlaps := 0
    for sec in 30:
        for i in 20:
            rel._process(0.05)
        var rects: Array = []
        for r in rel.rels:
            if r.tag.visible:
                rects.append(Rect2(r.pos + r.tag.position, r.tag.size))
        for i in rects.size():
            for j in range(i + 1, rects.size()):
                if rects[i].intersects(rects[j]):
                    overlaps += 1
    check("30 秒里称呼牌叠在一起 %d 次（挤成一团时让一块先收起来）" % overlaps, overlaps == 0)
    # 04 v7 新 2：称呼牌也不压桌牌（台前那一屏，大爸撞 1 号桌的桌牌）
    var t1c: Dictionary = h._table_cfg("T1")
    var sign_hits := 0
    for sec in 20:
        h.reset_to(h._cell_pos(h._nearest_free(h._cell_of(Vector2(float(t1c["x"]) - 120.0 + sec * 12.0, float(t1c["y"]) + 90.0)))))
        h.snap_cam()
        h._scan_chairs(1.0)
        h._process(0.0)
        for i in 10:
            rel._process(0.05)
        for k in h.table_signs:
            var sl: Label = h.table_signs[k]
            if not sl.visible:
                continue
            var sr := Rect2(sl.position, sl.size)
            for r in rel.rels:
                if r.tag.visible and Rect2(r.pos + r.tag.position, r.tag.size).intersects(sr):
                    sign_hits += 1
    check("称呼牌压桌牌 %d 次" % sign_hits, sign_hits == 0)
    # 屏幕边：挂着的牌子整块都在屏幕里（名字牌第一轮 B4 那条）
    var half: float = float(m.get_viewport().get_visible_rect().size.x) * 0.5 / h.cam.zoom.x
    var cx: float = h.cam.get_screen_center_position().x
    var cut := 0
    for sec in 20:
        # 人站在厅西边，镜头贴左墙；亲友走到屏幕边的机会多
        h.reset_to(h._cell_pos(h._nearest_free(h._cell_of(Vector2(150 + sec * 60, 1300)))))
        for i in 10:
            rel._process(0.05)
        h._process(0.0)
        half = float(m.get_viewport().get_visible_rect().size.x) * 0.5 / h.cam.zoom.x
        cx = h.cam.get_screen_center_position().x
        for r in rel.rels:
            if r.tag.visible:
                var x0: float = r.pos.x + r.tag.position.x
                if x0 < cx - half - 0.5 or x0 + r.tag.size.x > cx + half + 0.5:
                    cut += 1
    check("称呼牌不被屏幕左右边切（切到 %d 次）" % cut, cut == 0)

    print("4 开席：坐下、敬酒、打牌")
    rel.set_force("feast")
    st = {}
    await sim(rel, 80.0, st)
    var seated := 0
    var wrong_table: Array = []
    for r in rel.rels:
        if r.state == "sit":
            seated += 1
        if r.state == "sit" and not h.chair_world(h._table_cfg(r.table), r.chair).is_equal_approx(r.pos):
            wrong_table.append(r.title)
    check("坐下了 %d 位（去敬酒的那位可能还在路上）" % seated, seated >= 17)
    check("坐在自己那桌的椅子上（不对的 %s）" % [wrong_table], wrong_table.is_empty())
    check("有人去主桌敬酒（走过去 %d 步、举杯 %d 步）" % [int(st.get("go_toast", 0)), int(st.get("toast", 0))], int(st.get("go_toast", 0)) > 0 and int(st.get("toast", 0)) > 0)
    check("走回座位一路也不穿桌：出格 %d 次 %s" % [int(st.get("bad_free", 0)), st.get("bad_free_at", "")], int(st.get("bad_free", 0)) == 0)
    check("T11 打牌：牌摆出来了，一共出了 %d 张（桌上这会儿 %d 张）" % [rel.cards_dealt, rel.card_pile.size()], rel.cards_node.visible and rel.cards_dealt > 5)
    var cards_n := 0
    for r in rel.rels:
        if r.cards and r.state == "sit" and r.table == "T11":
            cards_n += 1
    check("打牌的是 T11 那四位（%d 位坐着）" % cards_n, cards_n == 4)
    # 敬酒的时候站在主桌边上
    var mt: Dictionary = h._table_cfg("MAIN")
    var toast_ok := true
    rel.toast_t = 0.0
    rel.toaster = null
    for i in 400:
        rel._process(0.05)
        if rel.toaster != null and rel.toaster.state == "toast":
            toast_ok = rel.toaster.pos.distance_to(Vector2(mt["x"], mt["y"])) < 130.0 and rel.toaster.cup.visible
            break
    check("敬酒站在主桌边、手上有杯", toast_ok)

    print("5 称呼：坐下了只亮跟前那位")
    var t9: Dictionary = h._table_cfg("T9")
    rel.toast_t = 999.0   # 这两节别让人走开去敬酒；正巧在敬酒路上的先坐回去
    rel.toaster = null
    for r in rel.rels:
        if r.state != "sit" and r.chair > 0:
            rel._sit_now(r)
    # 站到 T9 最靠前那位亲友的椅子跟前（10/2 十椅桌椅子圈转了 18°，桌子正前方没有椅子，不能写死站桌心正南）
    var front = null
    for r in rel.rels:
        if r.table == "T9" and r.state == "sit" and (front == null or r.pos.y > front.pos.y):
            front = r
    var at: Vector2 = front.pos + Vector2(0, 34) if front != null else Vector2(t9["x"], t9["y"]) + Vector2(0, float(t9["ry"]) + 30.0)
    h.reset_to(h._cell_pos(h._nearest_free(h._cell_of(at))))
    h.snap_cam()          # 镜头跟过来（不然牌子按原来镜头算都在屏幕外，全收了）
    rel._process(0.05)
    rel._process(0.05)   # 第一步算出谁在跟前，第二步按它亮称呼
    var lit: Array = []
    for r in rel.rels:
        if r.state == "sit" and r.tag.visible:
            lit.append(r.title)
    check("站在 T9 前面：坐着的只亮 %s（一位）" % [lit], lit.size() == 1 and rel.near_key != null and lit[0] == rel.near_key.title)

    print("6 身份卡")
    await frames(1)
    m._refresh_seat_buttons()
    check("冒「%s」" % m.rel_btn.text, m.rel_btn.visible and m.rel_btn.text == "看看" + rel.near_key.title)
    var who: String = rel.near_key.title
    m.rel_btn.emit_signal("pressed")
    await frames(2)
    var texts: Array = []
    if is_instance_valid(m.story_card):
        for l in m.story_card.find_children("*", "Label", true, false):
            texts.append((l as Label).text)
    check("身份卡：%s" % [texts], m.story_open and texts.size() == 2 and texts[0] == who and texts[1] == want[who])
    m._close_story_card()
    await frames(1)
    m._open_rel_card("四孃", "")
    await frames(1)
    texts.clear()
    for l in m.story_card.find_children("*", "Label", true, false):
        texts.append((l as Label).text)
    check("待讨论的（四孃）卡上只有称呼：%s" % [texts], texts == ["四孃"])
    m._close_story_card()
    await frames(1)

    print("7 真人坐了亲友的椅子")
    var dad = rel.find("大爸")
    if dad.state != "sit":   # 正巧在去敬酒的路上：先让他坐回去，这一节只验「真人占了他那把」
        rel.toaster = null
        rel._sit_now(dad)
    var old_chair: int = dad.chair
    var key := "T9:%d" % old_chair
    await sit(h, "T9", old_chair)
    check("我坐了大爸那把（%s）：大爸换到 %d 号（0 是这桌没空椅了，站在桌边 %s）" % [key, dad.chair, dad.state], str(h.my_seat.get("table_id", "")) == "T9" and dad.chair != old_chair
        and (dad.chair == 0 and dad.state == "stand" and h._free(dad.pos) or dad.chair > 0 and not h.seat_taken.has("T9:%d" % dad.chair)))
    h.stand_up()

    print("8 调试开关")
    m._build_debug()
    var fb: Button = m.dbg_panel.find_child("feast_toggle", true, false)
    check("日志面板有亲友开关：%s" % (fb.text if fb != null else "没有"), fb != null and fb.text == "亲友：强制开席（点一下换）" or (fb != null and fb.text.begins_with("亲友：")))
    m._set_feast_force("")
    fb.emit_signal("pressed")
    check("点一下：强制开席 %s" % fb.text, m.feast_force == "feast" and rel.force == "feast" and rel.feast)
    fb.emit_signal("pressed")
    check("再点：强制开席前 %s" % fb.text, m.feast_force == "pre" and not rel.feast)
    fb.emit_signal("pressed")
    check("再点：回到按北京时间", m.feast_force == "" and rel.force == "")

    await _crowd_tags(rel)

    print("9 切回第 44 版")
    await m._set_hall55(false)
    await create_timer(0.5).timeout
    check("第 44 版厅没有亲友（%s）、没有「看看」按钮（%s）" % [m.hall.life.relatives, m.rel_btn.visible], m.hall.life.relatives == null and not m.rel_btn.visible)
    DirAccess.remove_absolute(ProjectSettings.globalize_path(Main.HALL55_FLAG))

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)

func sit(h, tid: String, no: int) -> void:
    var t: Dictionary = h._table_cfg(tid)
    var c: Vector2 = h.chair_world(t, no)
    h.reset_to(h._stand_spot(c, h._seat_center(t)))
    await frames(1)
    m.near_seat_info = {"table_id": tid, "chair_no": no}
    m.sit_target = {"table_id": tid, "chair_no": no}
    m.sit_confirming = true
    m._on_sit_pressed()
    await create_timer(0.4).timeout


## 8b（04 10/2 第 3 条）：六位亲友挤在一小块（站着、牌都该亮），称呼牌照「跟前那位先、其余按离我近远」排：
## 亮着的牌两两不叠，谁都最多往上抬一行（不叠到别人头上），跟前那位一定亮
func _crowd_tags(rel) -> void:
    print("8b 一群亲友挤一块：称呼牌不叠、最多抬一行、跟前那位一定亮")
    var h = m.hall
    var at: Vector2 = h._cell_pos(h._nearest_free(h._cell_of(Vector2(400, 1450))))
    h.reset_to(at + Vector2(0, 60))
    h.snap_cam()
    var crowd: Array = []
    var k := 0
    for r in rel.rels:
        if k >= 6:
            break
        rel._stand_up(r)
        r.state = "idle"
        r.wait = 999.0
        r.path.clear()
        r.pos = at + Vector2(-50.0 + 20.0 * float(k), 18.0 * float(k % 2))
        r.node.position = r.pos
        crowd.append(r)
        k += 1
    rel.toast_t = 999.0
    rel._process(0.05)
    rel._process(0.05)
    var shown: Array = []
    var lifted_ok := true
    for r in crowd:
        if not r.tag.visible:
            continue
        shown.append(Rect2(r.pos + r.tag.position, r.tag.size))
    var overlap := false
    for i in shown.size():
        for j in range(i + 1, shown.size()):
            if (shown[i] as Rect2).intersects(shown[j]):
                overlap = true
    # 抬了几行：同一位亲友，牌子下沿离头顶的距离不超过一行牌高 + 间距
    for r in crowd:
        if r.tag.visible:
            var head_gap: float = -(r.tag.position.y + r.tag.size.y)
            var one_row: float = r.tag.size.y + rel.TAG_GAP
            var h_top: float = h._px_h(r.pos.y)
            if head_gap - h_top > one_row + 4.0:
                lifted_ok = false
    var near_shown: bool = rel.near_key != null and rel.near_key.tag.visible
    check("挤一块的 6 位：亮着 %d 张，两两不叠（%s）、最多抬一行（%s）、跟前那位 %s 亮着（%s）" % [
        shown.size(), not overlap, lifted_ok, rel.near_key.title if rel.near_key != null else "（没有）", near_shown],
        not overlap and lifted_ok and near_shown and shown.size() >= 1)
