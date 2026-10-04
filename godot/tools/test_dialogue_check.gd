extends SceneTree
## 对话插件 Dialogue Manager 接进游戏（dialogue01 08312ae，第 62 版）的功能测试（01 G 10/4 派，03 写）。不改游戏代码；存档指到临时文件。
##   1 插件在：DialogueManager 单例、奶奶的 .dialogue 导入了能加载、第一句拿得到
##   2 奶奶那段：三句 + 三选一（新娘那边 / 新郎那边 / 先不说，05 10/4 把「的」去了），三支各走到底：每一句的字、人物图（[#smile] [#talk] [#surprise] 换图）、名字牌对；
##     有选项那句点对话框不往下走、只有点选项才往下；选完回一句，最后「喝口茶，歇一下再去吃席」，说完收、能走
##   3 选项按钮（阿鱼 10/4 定的新规矩，05 回执「跟新规矩冲突的 4 个测试」）：选项在对话框**里面**最后一行、一行排完：手机 540×960、长屏下每个选项整块在框里、不出框、不压名字牌和头像、高 ≥ 44、宽 ≥ 88、互不叠、一个挨一个排成一行（同一高度）；choices_fit 说放得下（奶奶三个选项要 316、有 328）；一行排不下就算错（报 01，别换两行）
##   6 翻页（新规矩）：点一下先出完这一页、有下一页先翻页、最后一页才出选项
##   7 点头像或名字牌开身份卡（新规矩）
##   4 爷爷、叔叔、阿姨照旧念 lounge.json 的三句、没有选项；坐在沙发中间聊奶奶；有选项时开关身份卡不弄坏；冒泡说话期间停、说完照冒
##   5 「能说话的 NPC」通用：在迎宾院、草坪、湖边、果园各挑一个 NPC，运行时临时给他挂奶奶那段 .dialogue（不改布局文件、不提交），点他 → 走过去 → 开同一个对话框 → 走完能走；
##     没挂的 NPC、点地面照旧走路
## 用法：Godot --headless --path . --script res://tools/test_dialogue_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DialogSkin = preload("res://scripts/ui/dialog_skin.gd")
const DT := 1.0 / 60.0
const DLG := "res://assets/backhall/dialogue/lounge_09.dialogue"

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
        m.cv._process(DT)
        ui.sync()

func reenter(cn := "backhall") -> void:
    m.switching = false
    if m.state != cn:
        m._show_canvas(cn)
        m._goto(cn)
    var c = canvas_of(cn)
    c.walking_enabled = true
    c.stick = Vector2.ZERO
    if ui.is_open():
        ui.hide_all()

func canvas_of(n: String):
    return {"court": m.court, "backhall": m.backhall, "lawn": m.lawn, "lake": m.lake, "orchard": m.orchard}[n]

func tap_world(c, p: Vector2) -> void:
    c.tap(c.get_viewport().get_canvas_transform() * p)

## 等对话框弹出（走插件的要等插件给第一句）
func wait_talk(secs := 40.0) -> bool:
    for i in int(secs / DT):
        m.cv._process(DT)
        await process_frame
        if ui.talk_box.visible and ui.line_raw != "":
            return true
    return false

func wait_line_change(old: String, secs := 3.0) -> bool:
    for i in int(secs / DT):
        await process_frame
        if ui.line_raw != old or not ui.talk_box.visible:
            return true
    return false

func pose_of() -> String:
    return str(ui.portrait.get_meta("pose", ""))

func click_box() -> void:
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    ui.talk_box.gui_input.emit(ev)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_dlg_court.json"
    m.games_save.local_path = "user://test_dlg_games.json"
    m.orchard_save.local_path = "user://test_dlg_orchard.json"
    for cn in ["backhall", "lawn", "lake", "orchard"]:
        m.ensure_canvas(cn)
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    b = m.backhall
    life = b.lounge
    ui = m.lounge_ui
    ui.attach(life)
    var door := Vector2(1032, 690)   # 10/4 方案 C：后厅四间整间平移（化妆间 +1195、休息室 +528、麻将室 −144），下面的坐标照平移后的写

    print("1 插件")
    var dm = get_root().get_node_or_null("DialogueManager")
    check("DialogueManager 单例在", dm != null)
    var res = load(DLG)
    check("奶奶的 .dialogue 导入了、能加载（%s）" % str(res), res != null)
    var first = await dm.get_next_dialogue_line(res, "start")
    check("第一句拿得到：「%s」（谁说的 %s，标签 %s）" % [str(first.text), str(first.character), str(first.tags)], first != null and str(first.text) == "哎呀，你来啦" and str(first.character) == "奶奶" and first.tags.has("smile"))

    print("2 奶奶那段：三句 + 三选一，三支各走到底")
    var branches := [
        ["新娘那边", "那我们是一家人嘛，多坐会儿", "smile"],
        ["新郎那边", "欢迎欢迎，路上辛苦了", "surprise"],
        ["先不说", "好好好，不问了，喝茶喝茶", "smile"],
    ]
    var bad2: Array = []
    for bi in branches.size():
        reenter()
        b.reset_to(door)
        var issues: Array = []
        tap_world(b, (life.person("lounge_09")["head"] as Vector2) + Vector2(0, 20))
        var okt := await wait_talk()
        if not okt:
            bad2.append("分支 %d：没弹对话框" % (bi + 1))
            continue
        # 第 1 句
        if ui.line_raw != "哎呀，你来啦" or pose_of() != "smile" or ui.name_label.text != "奶奶" or ui.portrait.texture == null:
            issues.append("第 1 句不对（%s / %s / %s）" % [ui.line_raw, pose_of(), ui.name_label.text])
        if ui.choices.visible:
            issues.append("第 1 句就出选项了")
        if b.walking_enabled:
            issues.append("说话时还能走")
        # 点对话框往下
        var old: String = ui.line_raw
        click_box()
        await wait_line_change(old)
        if ui.line_raw != "坐嘛，这沙发软和得很" or pose_of() != "talk":
            issues.append("第 2 句不对（%s / %s）" % [ui.line_raw, pose_of()])
        old = ui.line_raw
        click_box()
        await wait_line_change(old)
        # 第 3 句：有选项
        if ui.line_raw != "你是哪边的客人呀？" or not ui.choices.visible:
            issues.append("第 3 句不对（%s、选项出着 %s）" % [ui.line_raw, ui.choices.visible])
        var texts: Array = []
        for ch in ui.choices.get_children():
            if not ch.is_queued_for_deletion():
                texts.append((ch as Button).text)
        if texts != ["新娘那边", "新郎那边", "先不说"]:
            issues.append("选项 %s" % str(texts))
        if ui.hint_label.text != "":
            issues.append("有选项时底下还写「点一下继续」")
        # 有选项时点对话框不往下走
        var before: String = ui.line_raw
        click_box()
        ui.next_line()
        await frames(10)
        if ui.line_raw != before or not ui.choices.visible:
            issues.append("有选项时点对话框往下走了（%s）" % ui.line_raw)
        # 开关身份卡，选项不丢
        ui.card_btn.pressed.emit()
        await frames(3)
        var card_open: bool = ui.card != null
        ui.close_card()
        await frames(3)
        if not card_open or not ui.choices.visible or ui.line_raw != before:
            issues.append("身份卡开关把选项弄坏了（开 %s、选项 %s）" % [card_open, ui.choices.visible])
        # 点选项
        var btns: Array = ui.choices.get_children().filter(func(x): return not x.is_queued_for_deletion())
        (btns[bi] as Button).pressed.emit()
        await wait_line_change(before)
        if ui.line_raw != str(branches[bi][1]) or pose_of() != str(branches[bi][2]) or ui.choices.visible:
            issues.append("选了「%s」回的话不对（%s / %s / 选项 %s）" % [branches[bi][0], ui.line_raw, pose_of(), ui.choices.visible])
        old = ui.line_raw
        click_box()
        await wait_line_change(old)
        if ui.line_raw != "喝口茶，歇一下再去吃席" or pose_of() != "talk":
            issues.append("最后一句不对（%s / %s）" % [ui.line_raw, pose_of()])
        old = ui.line_raw
        click_box()
        await frames(20)
        if ui.talk_box.visible or ui.talk_id != "" or life.talking != "":
            issues.append("说完没收")
        if not b.walking_enabled:
            issues.append("说完不能走")
        if not issues.is_empty():
            bad2.append("分支 %d（%s）：%s" % [bi + 1, branches[bi][0], "；".join(issues)])
    for l in bad2:
        print("    ", l)
    check("三支（新娘那边 / 新郎那边 / 先不说）各走到底：字、换图、名字牌、选项不往下走、说完收能走（%d 支有问题）" % bad2.size(), bad2.is_empty())

    print("3 选项在对话框里、一行放完（手机、长屏）")
    var bad3: Array = []
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        reenter()
        b.reset_to(door)
        tap_world(b, (life.person("lounge_09")["head"] as Vector2) + Vector2(0, 20))
        if not await wait_talk():
            bad3.append("%dx%d 没弹对话框" % [sz.x, sz.y])
            continue
        for k in 2:
            var o: String = ui.line_raw
            click_box()
            await wait_line_change(o)
        await frames(4)
        var vr: Rect2 = ui.get_viewport_rect()
        var box_r: Rect2 = ui.talk_box.get_global_rect()
        var plate_r: Rect2 = ui.name_plate.get_global_rect()
        var face_r := Rect2()
        var face_node: Control = ui.portrait.get_parent() as Control
        if face_node != null and face_node.visible and ui.portrait.visible:
            face_r = face_node.get_global_rect()
        var btns3: Array = ui.choices.get_children().filter(func(x): return not x.is_queued_for_deletion())
        if btns3.size() != 3:
            bad3.append("%dx%d 选项有 %d 个（该 3 个）" % [sz.x, sz.y, btns3.size()])
        var rs3: Array = []
        for ch in btns3:
            var r: Rect2 = (ch as Button).get_global_rect()
            rs3.append(r)
            var nm: String = (ch as Button).text
            if not vr.encloses(r):
                bad3.append("%dx%d「%s」不全在屏里（%s，屏 %s）" % [sz.x, sz.y, nm, str(r), str(vr)])
            if not box_r.encloses(r):
                bad3.append("%dx%d「%s」不全在对话框里面（%s，框 %s）" % [sz.x, sz.y, nm, str(r), str(box_r)])
            if r.intersects(plate_r):
                bad3.append("%dx%d「%s」压到名字牌（%s 对 %s）" % [sz.x, sz.y, nm, str(r), str(plate_r)])
            if face_r.size.x > 0.0 and r.intersects(face_r):
                bad3.append("%dx%d「%s」压到头像（%s 对 %s）" % [sz.x, sz.y, nm, str(r), str(face_r)])
            if r.size.y < 44.0 or r.size.x < 88.0:
                bad3.append("%dx%d「%s」太小 %s（要 高 ≥ 44、宽 ≥ 88）" % [sz.x, sz.y, nm, str(r.size)])
        # 一行：同一高度、从左到右一个挨一个不叠
        for i in rs3.size():
            for j2 in range(i + 1, rs3.size()):
                if (rs3[i] as Rect2).intersects(rs3[j2]):
                    bad3.append("%dx%d 选项 %d、%d 叠在一起" % [sz.x, sz.y, i, j2])
            if absf((rs3[i] as Rect2).position.y - (rs3[0] as Rect2).position.y) > 1.0 or absf((rs3[i] as Rect2).size.y - (rs3[0] as Rect2).size.y) > 1.0:
                bad3.append("%dx%d 选项 %d 跟第 1 个不在同一行（y %.0f 对 %.0f）" % [sz.x, sz.y, i, (rs3[i] as Rect2).position.y, (rs3[0] as Rect2).position.y])
            if i > 0 and (rs3[i] as Rect2).position.x < (rs3[i - 1] as Rect2).end.x:
                bad3.append("%dx%d 选项 %d 不在第 %d 个右边" % [sz.x, sz.y, i, i - 1])
        var fit: Dictionary = DialogSkin.choices_fit(ui.talk_box)
        print("    %dx%d：选项大小 %s、整排 %s、对话框 %s；一行要 %s、有 %s（05 说奶奶三个要 316、有 328）" % [sz.x, sz.y, str(rs3.map(func(r): return r.size)), str(ui.choices.get_global_rect()), str(box_r), str(fit.get("need")), str(fit.get("have"))])
        if not bool(fit.get("ok", false)):
            bad3.append("%dx%d 一行排不下（要 %s、有 %s）——报 01，别换两行" % [sz.x, sz.y, str(fit.get("need")), str(fit.get("have"))])
        ui.close_talk()
    get_root().size = Vector2i(540, 960)
    for l in bad3:
        print("    ", l)
    check("手机、长屏：选项在对话框里面、一行排完、不压名字牌和头像、够大（高 ≥ 44、宽 ≥ 88）、互不叠、choices_fit 说放得下（%d 处有问题）" % bad3.size(), bad3.is_empty())

    print("4 别的三位照旧、坐着聊、冒泡")
    var data_people: Dictionary = life.data["people"]
    var bad4: Array = []
    for id in ["lounge_10", "lounge_05", "lounge_06"]:
        reenter()
        b.reset_to(door)
        life.person(id)["wait"] = 999.0
        tap_world(b, (life.person(id)["head"] as Vector2) + Vector2(0, 20))
        var issues: Array = []
        if not await wait_talk():
            bad4.append("%s 没弹对话框" % id)
            continue
        var lines: Array = data_people[id]["talk"]
        for j in lines.size():
            if ui.line_raw != str(lines[j]["text"]) or ui.choices.visible:
                issues.append("第 %d 句 %s（选项 %s）" % [j + 1, ui.line_raw, ui.choices.visible])
            ui.next_line()
            await frames(2)
        if ui.talk_box.visible or not b.walking_enabled:
            issues.append("说完没收或不能走")
        if not issues.is_empty():
            bad4.append("%s：%s" % [id, "；".join(issues)])
    for l in bad4:
        print("    ", l)
    check("爷爷、叔叔、阿姨：照旧念 lounge.json 三句、没有选项、说完收（%d 位有问题）" % bad4.size(), bad4.is_empty())
    # 坐着聊奶奶
    reenter()
    b.reset_to(door)
    var sm: Dictionary = life.seat_by_id("sofa_m")
    b.reset_to(sm["stand"])
    life.sit(sm)
    tick(90)
    ui.sync()
    check("坐在沙发中间：出「跟奶奶聊聊」", b.seated and ui.talk_btn.visible and ui.near_id != "")
    print("    坐中间时「聊聊」指的是 %s（按钮「%s」）" % [ui.near_id, ui.talk_btn.text])
    life.request_talk("lounge_09")     # 坐在奶奶旁边直接聊奶奶（近的那位可能是爷爷，所以直接点名）
    var talk_ok := await wait_talk()
    check("坐着跟奶奶聊：弹对话框（走插件）、人还坐着", talk_ok and b.seated and ui.dm_res != null)
    check("坐着聊时第一句对（%s）" % ui.line_raw, ui.line_raw == "哎呀，你来啦")
    # 说话期间奶奶那一组冒泡停
    life.frozen = false
    for i in 240:
        life.step(DT)
    var g_bubble := false
    for id in ["lounge_09", "lounge_10"]:
        if life.bubble_text(id) != "":
            g_bubble = true
    check("说话期间奶奶爷爷那组不冒泡", not g_bubble)
    ui.close_talk()
    tick(5)
    var after := false
    for i in int(20.0 / DT):
        life.step(DT)
        if life.bubble_text("lounge_09") != "" or life.bubble_text("lounge_10") != "":
            after = true
            break
    check("说完这一组照冒泡", after)
    b.stand_up()
    tick(60)

    print("5 能说话的 NPC 通用：别的画布临时挂 .dialogue")
    var bad5: Array = []
    for cn in ["court", "lawn", "lake", "orchard"]:
        reenter(cn)
        var c = canvas_of(cn)
        # 挑一个 NPC：脚点能走到跟前的
        var pick_id := ""
        var foot := Vector2.ZERO
        for n in c.cfg.get("npcs", []):
            var id2 := str(n["id"])
            var f2 := Vector2(float(n["x"]), float(n["y"]))
            # 站着、脚前 72 像素内有能站的地方（船里、水里的 NPC 玩家走不到跟前，挂了台词也点不开，本来就这样，不挑）
            if c.npc_nodes.has(id2) and not bool(n.get("sit", false)) and c.nearest_free(f2 + Vector2(0, 30)) != Vector2.ZERO:
                pick_id = id2
                foot = f2
                break
        if pick_id == "":
            print("    %s：没有站着的 NPC，NPC 有 %s、节点有 %s" % [cn, str((c.cfg.get("npcs", []) as Array).map(func(n): return n["id"])), str(c.npc_nodes.keys())])
        if pick_id == "":
            bad5.append("%s 里没挑到 NPC" % cn)
            continue
        c.add_talker(pick_id, foot, 84.0, DLG, "测试老人", "LM-GUEST-09")
        c.reset_to(c.nearest_free(foot + Vector2(0, 150)) if c._free(foot + Vector2(0, 150)) == false else foot + Vector2(0, 150))
        var issues: Array = []
        # 点地面照旧走路（不在他身上）
        var far: Vector2 = c.pos + Vector2(60, 0)
        if not c._free(far):
            far = c.pos + Vector2(-60, 0)
        c.path.clear()
        tap_world(c, far)
        if c.path.is_empty() and c.pending_talker != "":
            issues.append("点地面被当成点人")
        c.path.clear()
        # 点他身上
        tap_world(c, foot + Vector2(0, -30))
        if c.pending_talker != pick_id and not ui.talk_box.visible:
            issues.append("点他身上没反应（pending %s）" % c.pending_talker)
        var okt := await wait_talk(60.0)
        if not okt:
            var ap: Vector2 = c.talker_approach(pick_id) if c.talkers.has(pick_id) else Vector2.ZERO
            var pth: Array = c.find_path(c.pos, ap) if ap != Vector2.ZERO else []
            bad5.append("%s：%s 没弹对话框（%s；他脚点 %s、玩家站 %s、走到他跟前的点 %s、寻路 %d 段；他脚点能站 %s）" % [cn, pick_id, "；".join(issues), str(foot), str(c.pos), str(ap), pth.size(), c._free(foot)])
            c.talkers.erase(pick_id)
            continue
        if ui.name_label.text != "奶奶" or ui.line_raw != "哎呀，你来啦":
            issues.append("第一句不对（%s / %s）" % [ui.name_label.text, ui.line_raw])
        if c.walking_enabled:
            issues.append("说话时还能走")
        # 一路点到选项，选第一个，点完
        for k in 2:
            var o: String = ui.line_raw
            click_box()
            await wait_line_change(o)
        var cnt := 0
        for ch in ui.choices.get_children():
            if not ch.is_queued_for_deletion():
                cnt += 1
        if cnt != 3:
            issues.append("没出三个选项（%d）" % cnt)
        var btns: Array = ui.choices.get_children().filter(func(x): return not x.is_queued_for_deletion())
        var bef: String = ui.line_raw
        (btns[0] as Button).pressed.emit()
        await wait_line_change(bef)
        for k in 2:
            var o2: String = ui.line_raw
            click_box()
            await wait_line_change(o2)
        await frames(10)
        if ui.talk_box.visible or ui.talk_id != "":
            issues.append("说完没收")
        if not c.walking_enabled:
            issues.append("说完不能走")
        c.talkers.erase(pick_id)
        # 没挂的：点他不会开聊
        tap_world(c, foot + Vector2(0, -30))
        await frames(3)
        if ui.talk_box.visible:
            issues.append("拿掉以后点他还开聊")
        print("    %s：NPC %s（脚点 %s）：%s" % [cn, pick_id, str(foot), "全对" if issues.is_empty() else "；".join(issues)])
        if not issues.is_empty():
            bad5.append("%s：%s" % [cn, "；".join(issues)])
    for l in bad5:
        print("    ", l)
    check("迎宾院、草坪、湖边、果园：临时挂 .dialogue 的 NPC 点他 → 走过去 → 开同一个对话框 → 走完能走；点地面照旧走路（%d 处有问题）" % bad5.size(), bad5.is_empty())
    print("6 翻页：点一下先出完这一页、有下一页先翻页、最后一页才出选项（05 回执新规矩）")
    var long_txt := "这一句特别特别长，长到一页根本放不下：奶奶从早上起来就一直在忙，先去厨房看了看汤，又去后院摘了些青菜，回来还要把喜糖一颗一颗装进小袋子里，装完了再把桌上的茶杯摆整齐，你说累不累呀，不过今天高兴，累也值得。"
    var res6 = dm.create_resource_from_text("~ start\n奶奶: " + long_txt + "\n- 好\n\t奶奶: 好嘞\n- 不好\n\t奶奶: 行吧\n=> END")
    var typer = ui.talk_box.get_node_or_null("typer")
    var inst_was: bool = typer.instant
    typer.instant = false   # 测试里平时是整页直接出；这一节要真打字
    var p6: Dictionary = (life.person("lounge_09") as Dictionary).duplicate()
    p6["talk"] = [{"text": "x", "pose": "front"}]
    p6["dialogue"] = ""
    reenter()
    b.reset_to(door)
    ui._open(p6, b)
    ui.dm_res = res6
    ui._dm_next("start")
    for i in 120:
        await process_frame
        if ui.line_label.text == long_txt and typer.pages.size() >= 1:
            break
    await frames(3)
    var issues6: Array = []
    var np: int = typer.pages.size()
    if np < 2:
        issues6.append("长句只分了 %d 页（该 ≥ 2）" % np)
    if not ui.choices.visible:
        issues6.append("这句带选项，choices 该已经建好")
    if not DialogSkin.typing(ui.talk_box):
        issues6.append("刚开口字该还在一个个出（没在出）")
    if ui.choices.modulate.a > 0.01:
        issues6.append("第一页选项就露出来了（透明度 %.2f）" % ui.choices.modulate.a)
    var line_before: String = ui.line_label.text
    click_box()
    await frames(2)
    if DialogSkin.typing(ui.talk_box) or typer.page != 0:
        issues6.append("第一下点该只是把这一页出完（还在出 %s、页 %d）" % [str(DialogSkin.typing(ui.talk_box)), typer.page])
    var flips := 0
    var early_choice := false
    for step in 12:
        if typer.page >= np - 1:
            break
        click_box()
        await frames(2)
        flips += 1
        if DialogSkin.typing(ui.talk_box):
            click_box()
            await frames(2)
        if typer.page < np - 1 and (ui.choices.modulate.a > 0.01 or (ui.choices.get_child(0) as Control).mouse_filter == Control.MOUSE_FILTER_STOP):
            early_choice = true
    if typer.page != np - 1:
        issues6.append("点了 %d 次没翻到最后一页（页 %d / %d）" % [flips, typer.page, np])
    if early_choice:
        issues6.append("没到最后一页选项就露出来 / 能点了")
    if ui.line_label.text != line_before:
        issues6.append("翻页的时候句子换了（该一直是这一句）")
    await frames(3)
    if DialogSkin.typing(ui.talk_box):
        click_box()
        await frames(2)
    var last_btn: Button = ui.choices.get_child(0) as Button
    if ui.choices.modulate.a < 0.99 or last_btn.mouse_filter != Control.MOUSE_FILTER_STOP:
        issues6.append("最后一页选项该露出来、能点（透明度 %.2f）" % ui.choices.modulate.a)
    click_box()
    await frames(3)
    if ui.line_label.text != line_before or not ui.choices.visible:
        issues6.append("最后一页有选项时点对话框往下走了")
    (ui.choices.get_child(0) as Button).pressed.emit()
    await wait_line_change(line_before)
    if ui.line_label.text != "好嘞":
        issues6.append("点了第一个选项回的话不对（%s）" % ui.line_label.text)
    ui.close_talk()
    typer.instant = inst_was
    check("长句分 %d 页：第一下点出完这一页、再点才翻页、翻到最后一页选项才露出来能点、最后一页有选项点框不往下走（%d 处不对 %s）" % [np, issues6.size(), str(issues6)], issues6.is_empty())

    print("7 点头像或名字牌开身份卡")
    var issues7: Array = []
    for which in ["头像", "名字牌"]:
        reenter()
        b.reset_to(door)
        tap_world(b, (life.person("lounge_09")["head"] as Vector2) + Vector2(0, 20))
        if not await wait_talk():
            issues7.append("%s：没弹对话框" % which)
            continue
        await frames(4)
        var target: Control = (ui.portrait.get_parent() as Control) if which == "头像" else ui.name_plate
        var ev := InputEventMouseButton.new()
        ev.button_index = MOUSE_BUTTON_LEFT
        ev.pressed = true
        target.gui_input.emit(ev)
        await frames(4)
        if ui.card == null:
            issues7.append("%s：点了没开身份卡" % which)
        else:
            var shown_name := false
            for n7 in ui.card.find_children("*", "Label", true, false):
                if (n7 as Label).text == "奶奶":
                    shown_name = true
            if not shown_name:
                issues7.append("%s：身份卡上没写「奶奶」" % which)
        ui.close_card()
        await frames(2)
        if ui.card != null:
            issues7.append("%s：身份卡关不掉" % which)
        ui.close_talk()
    check("点头像、点名字牌各开一次身份卡（上面写「奶奶」）、都能关（%d 处不对 %s）" % [issues7.size(), str(issues7)], issues7.is_empty())

    print("RESULT " + ("PASS" if ok else "FAIL"))
    quit(0 if ok else 1)
