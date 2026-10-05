extends SceneTree
## 第 69 版收尾：阿鱼 10/4 新规矩——对话卡片里人说的话加“”，冒泡、旁白、顶部提示不加（07 做；07 把 20 份测试机械换成读原文，所以没有测试在管「加没加」），03 自己重测（01 H 10/4 派，不改游戏代码）：
##   1 quoted()：普通一句加“”、已经带“开头的不再加、空串不加；原文里不该自己带引号（游戏里所有能点出来的人物台词、冒泡台词、说话框台词扫一遍）
##   2 说话框 _say：有说话人的（新娘妈妈、摄影师…、默认的阿鱼）加；说话人空的（下车提示）不加；顶部提示条 _note（到了 XX、这边过不去了）不加；
##     说话框存的原文 said_raw 不带引号，名字牌不加引号
##   3 点人说话弹出来的对话框：每一块画布上每一个能点的人（休息间四位、麻将室、化妆间、迎宾院老人、别的块上布局写了 dialogue 的 NPC），
##     从第一句翻到最后一句（有选项的每个选项各走一遍）：每一页的字 == “原文”，原文非空、不自带引号，名字牌没引号
##   4 人头顶的冒泡：直接冒（show_bubble）和真等 40 秒让它自己冒，字里没有“ ”；冒泡字是原文
## 用法：Godot --headless --path . --script res://tools/test_quotes_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DT := 1.0 / 30.0
const LQ := "“"
const RQ := "”"

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(250.0).timeout.connect(func():
        print("RESULT FAIL 250 秒没跑完")
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

func go_canvas(k: String) -> void:
    m.switching = false
    m.ensure_canvas(k)
    m._show_canvas(k)
    m._goto(k)
    m.cv.walking_enabled = true
    m.cv.stick = Vector2.ZERO
    m.cv.path.clear()

func canvas_of(k: String):
    if k == "court":
        return m.court
    return m._canvas_by(k)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_qc_court.json"
    m.games_save.local_path = "user://test_qc_games.json"
    await m._enter_court()
    m.dialog.visible = false

    print("1 quoted()")
    check("普通一句加“”（%s）" % m.quoted("你好"), m.quoted("你好") == LQ + "你好" + RQ)
    check("已经带“开头的不再加（%s）" % m.quoted(LQ + "你好" + RQ), m.quoted(LQ + "你好" + RQ) == LQ + "你好" + RQ)
    check("空串不加", m.quoted("") == "")
    var self_quoted: Array = []
    var scanned := 0
    for dir in ["res://assets/backhall/dialogue", "res://assets/entrance", "res://assets/areas", "res://assets/backhall"]:
        var da := DirAccess.open(dir)
        if da == null:
            continue
        for fn in da.get_files():
            if not (fn.ends_with(".dialogue") or fn.ends_with(".json")):
                continue
            var txt := FileAccess.get_file_as_string(dir + "/" + fn)
            scanned += 1
            for ln in txt.split("\n"):
                var s := ln.strip_edges()
                if fn.ends_with(".dialogue"):
                    # .dialogue 里一句话是「角色: 话」或单独一行的话；开头就是“的算自带引号
                    var body := s.substr(s.find(":") + 1).strip_edges() if ":" in s else s
                    if body.begins_with(LQ):
                        self_quoted.append("%s：%s" % [fn, s.substr(0, 30)])
                else:
                    if ("\"text\": \"" + LQ) in s or ("\"text\":\"" + LQ) in s:
                        self_quoted.append("%s：%s" % [fn, s.substr(0, 30)])
    for x in self_quoted:
        print("    ", x)
    check("台词原文（%d 份 .dialogue / .json）里没有自己带“开头的一句（%d 处）" % [scanned, self_quoted.size()], self_quoted.is_empty() and scanned >= 3)   # 导出包里没有原始 .dialogue 文件，只剩 json，所以只要求扫到 3 份以上

    print("2 说话框、顶部提示条")
    m._say("你们来啦", -1.0, "新娘妈妈")
    await frames(2)
    check("有说话人（新娘妈妈）：字是“原文”、存的原文不带引号、名字牌没引号（%s / %s / %s）" % [m.dialog_text.text, m.said_raw, m.dialog_who.text], m.dialog_text.text == LQ + "你们来啦" + RQ and m.said_raw == "你们来啦" and m.dialog_who.text == "新娘妈妈")
    m._say("我到啦")
    await frames(2)
    check("默认说话人（阿鱼）：也是人说的话，加（%s / %s）" % [m.dialog_text.text, m.dialog_who.text], m.dialog_text.text == LQ + "我到啦" + RQ)
    m._say("出阁宴在宴会厅 先去迎宾院签个到", -1.0, "")
    await frames(2)
    check("说话人空的（下车提示那种）：不加（%s）" % m.dialog_text.text, m.dialog_text.text == "出阁宴在宴会厅 先去迎宾院签个到" and not m.dialog_text.text.contains(LQ))
    m._say("说一句带引号的", -1.0, "摄影师")
    await frames(2)
    m._note("到了后花园", 1.0)
    await frames(2)
    check("顶部提示条 _note（到了后花园）：不加（%s）" % m.note.text, m.note.text == "到了后花园" and not m.note.text.contains(LQ))
    m.dialog.visible = false
    var lj = JSON.parse_string(FileAccess.get_file_as_string("res://assets/entrance/lines.json"))
    var park_who := str(lj["lines"]["park_sign"].get("who", "x"))
    check("下车提示 park_sign 的说话人是空的（%s），所以不加引号" % park_who, park_who == "")

    print("3 点人说话的对话框：每一块、每个人、每一页")
    var talkers_n := 0
    var skipped: Array = []
    var bad: Array = []
    var pages_n := 0
    var keys: Array = ["court", "backhall", "lawn", "lake", "orchard", "parking", "plaza"] + m.AREA_IDS
    for k in keys:
        m.dialog.visible = false
        go_canvas(k)
        await frames(2)
        var c = m.cv
        var ids: Array = []
        if k == "backhall":
            m.lounge_ui.attach(m.backhall.lounge)
            for lfx in m.lounge_ui.lives:   # 休息间四位、麻将室、化妆间的人各是一个 life
                for id in (lfx.people as Dictionary).keys():
                    var pd: Dictionary = lfx.person(str(id))
                    if str(pd.get("dialogue", "")) == "" and (pd.get("talk", []) as Array).is_empty():
                        skipped.append("%s/%s" % [k, str(id)])   # 没写台词的人点了不理（test_room_life 管），这里不测
                        continue
                    ids.append(["lounge", str(id)])
        if c.get("talkers") is Dictionary:
            for id in (c.talkers as Dictionary).keys():
                ids.append(["npc", str(id)])
        for pr in ids:
            var ui = m.lounge_ui
            if k == "backhall":
                ui.attach(m.backhall.lounge)
            if pr[0] == "lounge":
                ui.open_talk(pr[1])
            else:
                ui.open_npc(c, pr[1])
            for i in 200:
                await process_frame
                if ui.talk_box.visible and ui.line_raw != "":
                    break
            if not ui.talk_box.visible:
                bad.append("%s/%s：对话框没开" % [k, pr[1]])
                continue
            talkers_n += 1
            var branch := 0
            for page in 40:
                var raw: String = ui.line_raw
                var shown: String = ui.line_label.text
                pages_n += 1
                if raw == "" or raw.begins_with(LQ) or shown != LQ + raw + RQ or ui.name_label.text.contains(LQ):
                    bad.append("%s/%s 第 %d 页：原文「%s」显示「%s」名字牌「%s」" % [k, pr[1], page + 1, raw, shown, ui.name_label.text])
                if ui.choices.visible:
                    var btns: Array = ui.choices.get_children()
                    if btns.is_empty():
                        break
                    (btns[branch % btns.size()] as Button).pressed.emit()
                    branch += 1
                else:
                    ui.next_line()
                    await frames(2)
                    if not ui.talk_box.visible:
                        break
            ui.close_talk()
            await frames(2)
    for x in bad:
        print("    ", x)
    print("    没写台词所以没测的 %d 位：%s" % [skipped.size(), str(skipped)])
    check("%d 个人、%d 页：每一页字是“原文”、原文不自带引号、名字牌没引号（%d 处不对）" % [talkers_n, pages_n, bad.size()], bad.is_empty() and talkers_n >= 8 and pages_n >= 20)

    print("4 人头顶的冒泡")
    go_canvas("backhall")
    await frames(4)
    var qb: Array = []
    for lfx in m.lounge_ui.lives:
        var ids2: Array = (lfx.people as Dictionary).keys()
        if ids2.is_empty():
            continue
        lfx.show_bubble(str(ids2[0]), "胡了！♪")
        await frames(2)
        var b: Node2D = lfx.bubbles.get(str(ids2[0]))
        if b == null:
            qb.append("直接冒的泡没出来")
        else:
            for ch in b.find_children("*", "Label", true, false):
                var t := str((ch as Label).text)
                if t.contains(LQ) or t.contains(RQ) or t != "胡了！♪":
                    qb.append("直接冒的泡字「%s」" % t)
    var seen_n := 0
    for step in int(40.0 / DT):
        m.cv._process(DT)
        m._process(DT)
        if step % 15 == 0:
            for lfx in m.lounge_ui.lives:
                for id in lfx.bubbles:
                    var bb: Node2D = lfx.bubbles[id]
                    if is_instance_valid(bb):
                        for ch in bb.find_children("*", "Label", true, false):
                            seen_n += 1
                            var t2 := str((ch as Label).text)
                            if t2.contains(LQ) or t2.contains(RQ):
                                qb.append("自己冒的泡字「%s」带引号" % t2)
    for x in qb:
        print("    ", x)
    check("冒泡不带引号（直接冒 + 真等 40 秒量到 %d 次泡字；%d 处带引号）" % [seen_n, qb.size()], qb.is_empty() and seen_n > 0)

    DirAccess.remove_absolute("user://test_qc_court.json")
    DirAccess.remove_absolute("user://test_qc_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
