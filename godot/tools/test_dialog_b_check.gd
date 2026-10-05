extends SceneTree
## 对话框 B 第七轮（ui-dialog 41dba92，05 做，阿鱼 10/5：头像 3 倍只到胸口、话一页 2 行超过出上下翻页三角、点框不翻页），03 自己重测
## （01 H 10/5 派，不改游戏代码；不看 05 的 test_dialog_lift，另起量法；用真输入事件点，不只发按钮信号）：
##   1 翻页三角：长句（3 页）手机 540×960、长屏 585×1266 各一遍：每页 ≤ 2 行；第一页只有下三角、中间页上下都有、最后一页只有上三角；三角在话右边那一列、
##     整个在框里、能点范围 ≥ 44×44、两个三角不叠、不压名字牌和选项；真点（push_input 按下、松开）下三角翻到下一页、点上三角翻回；翻页句子不换、选项只在最后一页；
##     点框只把字出完、不翻页、不跳句；不到 2 行的话没有三角
##   2 头像：每位有头像的人（休息间四位、麻将室、化妆间的人）都是 3 倍整数倍；我自己量图（读图集里那一帧的不透明像素）：头顶到胸口的 43 行里人左右不切、
##     不压话、头大半在框上沿外面、下巴进框里；名字牌上有身份证小图标、真点名字牌 / 头像开身份卡
##   3 没头像的：化妆间新娘对话框不放头像（也不留上一个人的图）；阿鱼那个说话框没有头像、话用满宽
##   4 冒泡：白底（量图里框中间那个像素）、黑字；对话框开着时别的人头顶不冒（休息间、麻将室、化妆间）
## 用法：Godot --headless --path . --script res://tools/test_dialog_b_check.gd     最后一行 RESULT PASS 才算过
const Main = preload("res://scripts/main.gd")
const DialogSkin = preload("res://scripts/ui/dialog_skin.gd")
const LMPeople = preload("res://scripts/lm_people.gd")
const DT := 1.0 / 30.0

var m
var started := false
var ok := true
var b
var life
var ui
var typer
var door := Vector2(1032, 690)

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    get_root().add_child(m)
    create_timer(540.0).timeout.connect(func():
        print("RESULT FAIL 540 秒没跑完")
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

func reenter() -> void:
    m.switching = false
    if m.state != "backhall":
        m._show_canvas("backhall")
        m._goto("backhall")
    b.walking_enabled = true
    b.stick = Vector2.ZERO
    if ui.is_open():
        ui.hide_all()
    m.dialog.visible = false

## 进这份人所在的画布（休息间、麻将室在后厅；化妆间 10/4 起是单独一间屋 areas["makeup"]）
func enter_life(lf) -> void:
    m.switching = false
    if ui.is_open():
        ui.hide_all()
    m.dialog.visible = false
    if lf.room == "makeup":
        m.ensure_canvas("makeup")
        m._show_canvas("makeup")
        m._goto("makeup")
        var r = m.areas["makeup"]
        r.walking_enabled = true
        r.reset_to(r.SPAWN)
    else:
        reenter()
        b.reset_to(door)
    await frames(4)

## 真点：把按下、松开两个鼠标事件送进视口（窗口像素坐标），走完整的界面命中
func real_click(at_content: Vector2) -> void:
    var at: Vector2 = get_root().get_final_transform() * at_content   # push_input 要的是窗口像素；界面坐标（540 宽那套）按拉伸换过去（长屏 585 宽要乘 1.083）
    var e := InputEventMouseButton.new()
    e.button_index = MOUSE_BUTTON_LEFT
    e.position = at
    e.global_position = at
    e.pressed = true
    get_root().push_input(e)
    await process_frame
    var r := InputEventMouseButton.new()
    r.button_index = MOUSE_BUTTON_LEFT
    r.position = at
    r.global_position = at
    r.pressed = false
    get_root().push_input(r)
    await process_frame

func click_box_event() -> void:
    var ev := InputEventMouseButton.new()
    ev.button_index = MOUSE_BUTTON_LEFT
    ev.pressed = true
    ui.talk_box.gui_input.emit(ev)

var open_n := 0
func open_long(txt0: String, with_options := true, uniq := true) -> void:
    open_n += 1
    var tails: Array = ["", "啊", "呀", "哦", "嘛", "咯", "哈"]
    var txt: String = txt0 + ("" if not uniq else str(tails[open_n % 7]))
    var dm = get_root().get_node_or_null("DialogueManager")
    var body := "~ start\n奶奶: " + txt + "\n"
    if with_options:
        body += "- 好\n\t奶奶: 好嘞\n- 不好\n\t奶奶: 行吧\n"
    body += "=> END"
    var res = dm.create_resource_from_text(body)
    var p: Dictionary = (life.person("lounge_09") as Dictionary).duplicate()
    p["talk"] = [{"text": "x", "pose": "front"}]
    p["dialogue"] = ""
    reenter()
    b.reset_to(door)
    ui._open(p, b)
    ui.dm_res = res
    ui._dm_next("start")
    for i in 150:
        await process_frame
        if ui.line_raw == txt and typer.pages.size() >= 1:
            break
    await frames(4)
    if typer.typing():
        typer.finish()
    await frames(2)

func run() -> void:
    get_root().size = Vector2i(540, 960)
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    m.nickname = "小李"
    m.cloud.fake_no_news = true
    m.court_save.local_path = "user://test_dbc_court.json"
    m.games_save.local_path = "user://test_dbc_games.json"
    m.ensure_canvas("backhall")
    m.ensure_canvas("makeup")   # 化妆间单独成屋：它的人在 areas["makeup"].lives 里，要先搭好
    m._show_canvas("backhall")
    m._goto("backhall")
    await frames(3)
    b = m.backhall
    life = b.lounge
    ui = m.lounge_ui
    ui.attach(life)
    typer = ui.talk_box.get_node_or_null("typer")
    var long_txt := "这一句特别特别长，长到一页根本放不下：奶奶从早上起来就一直在忙，先去厨房看了看汤，又去后院摘了些青菜，回来还要把喜糖一颗一颗装进小袋子里，装完了再把桌上的茶杯摆整齐，你说累不累呀，不过今天高兴，累也值得。"
    var inst_was: bool = typer.instant
    typer.instant = false

    print("1 翻页三角")
    var bad1: Array = []
    var np_seen := 0
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        await open_long(long_txt)
        var np: int = typer.pages.size()
        np_seen = np
        var tag := "%dx%d" % [sz.x, sz.y]
        if np < 3:
            bad1.append("%s：长句只分 %d 页（该 ≥ 3）" % [tag, np])
        for pg in typer.pages:
            if (pg as String).count("\n") > 1:
                bad1.append("%s：有一页超过 2 行：「%s」" % [tag, pg])
        var box_r: Rect2 = ui.talk_box.get_global_rect()
        var line_before: String = ui.line_label.text
        var visited: Array = []
        for step in np + 2:
            await frames(3)
            if typer.typing():
                typer.finish()
                await frames(2)
            var pg_i: int = typer.page
            visited.append(pg_i)
            var up: bool = typer.up_btn.is_visible_in_tree()
            var dn: bool = typer.down_btn.is_visible_in_tree()
            var want_up: bool = pg_i > 0
            var want_dn: bool = pg_i < np - 1
            if up != want_up or dn != want_dn:
                bad1.append("%s 第 %d 页：上三角 %s（该 %s）、下三角 %s（该 %s）" % [tag, pg_i + 1, str(up), str(want_up), str(dn), str(want_dn)])
            # 几何：整个在框里、≥44×44、在话右边那一列、两个不叠、不压名字牌和选项
            var rects: Array = []
            for pr in [["上", typer.up_btn, up], ["下", typer.down_btn, dn]]:
                if not pr[2]:
                    continue
                var rr: Rect2 = (pr[1] as Control).get_global_rect()
                rects.append(rr)
                if not box_r.encloses(rr):
                    bad1.append("%s 第 %d 页 %s三角不全在框里（%s，框 %s）" % [tag, pg_i + 1, pr[0], str(rr), str(box_r)])
                if rr.size.x < 44.0 or rr.size.y < 44.0:
                    bad1.append("%s 第 %d 页 %s三角能点范围只有 %s（要 ≥ 44×44）" % [tag, pg_i + 1, pr[0], str(rr.size)])
                var text_r: Rect2 = typer.shown.get_global_rect()
                if rr.position.x < text_r.end.x - 1.0 and rr.intersects(text_r):
                    bad1.append("%s 第 %d 页 %s三角压到话（%s 对 %s）" % [tag, pg_i + 1, pr[0], str(rr), str(text_r)])
                if ui.name_plate.visible and rr.intersects(ui.name_plate.get_global_rect()):
                    bad1.append("%s 第 %d 页 %s三角压到名字牌" % [tag, pg_i + 1, pr[0]])
                if ui.choices.visible and ui.choices.modulate.a > 0.5:
                    for ch in ui.choices.get_children():
                        if not ch.is_queued_for_deletion() and rr.intersects((ch as Control).get_global_rect()):
                            bad1.append("%s 第 %d 页 %s三角压到选项" % [tag, pg_i + 1, pr[0]])
            if rects.size() == 2 and (rects[0] as Rect2).intersects(rects[1]):
                bad1.append("%s 第 %d 页 上下三角叠在一起" % [tag, pg_i + 1])
            # 选项只在最后一页
            var ch_vis: bool = ui.choices.modulate.a > 0.5
            if ch_vis != (pg_i == np - 1):
                bad1.append("%s 第 %d 页 选项 %s（只该在最后一页）" % [tag, pg_i + 1, "露着" if ch_vis else "没露"])
            if ui.line_label.text != line_before:
                bad1.append("%s 翻页时句子换了" % tag)
            # 点框：只出完字、不翻页、不跳句（不是最后一页时）
            if pg_i < np - 1:
                var shown_before: String = typer.shown.text
                click_box_event()
                await frames(3)
                if typer.page != pg_i or ui.line_label.text != line_before or typer.shown.text != shown_before:
                    bad1.append("%s 第 %d 页 点框翻页了 / 跳句了（页 %d）" % [tag, pg_i + 1, typer.page])
                # 真点下三角
                var c: Vector2 = typer.down_btn.get_global_rect().get_center()
                await real_click(c)
                await frames(2)
                if typer.page != pg_i + 1:
                    bad1.append("%s 第 %d 页 真点下三角没翻到下一页（页 %d）" % [tag, pg_i + 1, typer.page])
            else:
                break
        # 最后一页：真点上三角翻回
        if typer.page == np - 1:
            await frames(2)
            if typer.typing():
                typer.finish()
            var cu: Vector2 = typer.up_btn.get_global_rect().get_center()
            await real_click(cu)
            await frames(2)
            if typer.page != np - 2:
                bad1.append("%s 最后一页真点上三角没翻回上一页（页 %d）" % [tag, typer.page])
        else:
            bad1.append("%s 没翻到最后一页（页 %d / %d）" % [tag, typer.page, np])
        ui.close_talk()
        await frames(2)
    # 不到 2 行的话没有三角
    get_root().size = Vector2i(540, 960)
    await frames(4)
    var short_bad: Array = []
    for st in ["你好呀", "坐嘛，这沙发软和得很，莫客气，想吃啥拿啥"]:
        await open_long(st, false)
        await frames(3)
        if typer.pages.size() != 1 or typer.up_btn.is_visible_in_tree() or typer.down_btn.is_visible_in_tree():
            short_bad.append("「%s」分 %d 页、上三角 %s、下三角 %s" % [st, typer.pages.size(), str(typer.up_btn.is_visible_in_tree()), str(typer.down_btn.is_visible_in_tree())])
        ui.close_talk()
        await frames(2)
    for x in bad1 + short_bad:
        print("    ", x)
    check("长句 %d 页、手机和长屏：每页 ≤ 2 行；第一页只有下三角、中间页上下都有、最后一页只有上三角；三角在框里、≥ 44×44、不叠不压；真点下三角翻页、点上三角翻回；选项只在最后一页；点框不翻页不跳句（%d 处不对）" % [np_seen, bad1.size()], bad1.is_empty())
    check("不到 2 行 / 刚好 2 行的话没有三角（%d 处不对）" % short_bad.size(), short_bad.is_empty())

    # 关了再开同一句长话：该从第 1 页开始（不接着上回翻到的那页）
    var reopen_bad: Array = []
    for sz in [Vector2i(540, 960), Vector2i(585, 1266)]:
        get_root().size = sz
        await frames(4)
        await open_long(long_txt, true, false)
        var np2: int = typer.pages.size()
        for i in 2:
            typer.down_btn.pressed.emit()
            await frames(2)
            if typer.typing():
                typer.finish()
        var pg_before: int = typer.page
        ui.close_talk()
        await frames(3)
        await open_long(long_txt, true, false)
        var pg_after: int = typer.page
        var up_vis: bool = typer.up_btn.is_visible_in_tree()
        var ch_vis: bool = ui.choices.modulate.a > 0.5
        if pg_after != 0 or up_vis or ch_vis:
            reopen_bad.append("%dx%d：翻到第 %d 页关掉，再开同一句：落在第 %d 页（该第 1 页）、上三角 %s、选项露着 %s" % [sz.x, sz.y, pg_before + 1, pg_after + 1, str(up_vis), str(ch_vis)])
        ui.close_talk()
        await frames(3)
    get_root().size = Vector2i(540, 960)
    for x in reopen_bad:
        print("    ", x)
    check("翻到后面几页关掉、再开同一句：从第 1 页开始，没有上三角、选项不露（%d 处不对）" % reopen_bad.size(), reopen_bad.is_empty())

    print("2 头像")
    typer.instant = inst_was
    var face_bad: Array = []
    var people: Array = []
    var all_lives: Array = b.lives.duplicate()
    if m.areas.has("makeup") and m.areas["makeup"].get("lives") is Array:
        all_lives += m.areas["makeup"].lives   # 化妆间单独成屋以后，它的人不在后厅 lives 里
    for lf in all_lives:
        for id in lf.people.keys():
            var pd: Dictionary = lf.person(str(id))
            if str(pd.get("code", "")) != "" and (str(pd.get("dialogue", "")) != "" or not (pd.get("talk", []) as Array).is_empty()):
                people.append([lf, str(id)])
    for pr in people:
        var lf2 = pr[0]
        var id2: String = pr[1]
        await enter_life(lf2)
        tick(1)
        ui.open_talk(id2)
        for i in 200:
            await process_frame
            if ui.talk_box.visible and ui.line_raw != "":
                break
        await frames(6)
        if not ui.talk_box.visible:
            face_bad.append("%s：对话框没开" % id2)
            continue
        var tex: Texture2D = ui.portrait.texture
        var at := tex as AtlasTexture
        var face: Control = ui.portrait.get_parent() as Control
        if tex == null or at == null:
            face_bad.append("%s：没有头像" % id2)
            ui.close_talk()
            continue
        var k: float = ui.portrait.size.x / maxf(at.region.size.x, 1.0)
        if absf(k - 3.0) > 0.001 or absf(ui.portrait.size.y / maxf(at.region.size.y, 1.0) - 3.0) > 0.001:
            face_bad.append("%s：放大 %.2f 倍（要 3 倍整数倍）" % [id2, k])
        # 自己量图：头像那一帧前 43 行（face.size.y / 3 取整进位）里不透明像素的左右范围
        var img: Image = at.atlas.get_image()
        var rows: int = int(ceil(face.size.y / 3.0))
        var rx0 := int(at.region.position.x)
        var ry0 := int(at.region.position.y)
        var minx := 99999
        var maxx := -1
        var miny := 99999
        for yy in range(0, mini(rows, int(at.region.size.y))):
            for xx in int(at.region.size.x):
                if img.get_pixel(rx0 + xx, ry0 + yy).a > 0.5:
                    minx = mini(minx, xx)
                    maxx = maxi(maxx, xx)
                    miny = mini(miny, yy)
        if maxx < 0:
            face_bad.append("%s：前 %d 行是空的（没画人）" % [id2, rows])
        else:
            var left: float = ui.portrait.position.x + float(minx) * 3.0
            var right: float = ui.portrait.position.x + float(maxx + 1) * 3.0
            if left < -0.5 or right > face.size.x + 0.5:
                face_bad.append("%s：人左右被切（人占 %.0f～%.0f，头像块宽 %.0f）" % [id2, left, right, face.size.x])
            var top_gap: float = ui.portrait.position.y + float(miny) * 3.0
            if top_gap > 6.0:
                face_bad.append("%s：头顶离头像块上沿 %.0f 像素（头该顶着上沿）" % [id2, top_gap])
        var box_r2: Rect2 = ui.talk_box.get_global_rect()
        var face_r: Rect2 = face.get_global_rect()
        if face_r.position.y >= box_r2.position.y:
            face_bad.append("%s：头像没顶出框上沿（头像上沿 %.0f、框上沿 %.0f）" % [id2, face_r.position.y, box_r2.position.y])
        if face_r.end.y > box_r2.end.y + 1.0:
            face_bad.append("%s：头像掉出框下沿" % id2)
        if face_r.intersects(typer.shown.get_global_rect()):
            face_bad.append("%s：头像压到话" % id2)
        for ch in ui.choices.get_children():
            if not ch.is_queued_for_deletion() and ch.visible and face_r.intersects((ch as Control).get_global_rect()):
                face_bad.append("%s：头像压到选项" % id2)
        # 名字牌上的身份证图标；真点名字牌 / 头像开身份卡
        var icon = ui.name_plate.find_child("card_icon", true, false)
        if icon == null or (icon as TextureRect).texture == null or not (icon as TextureRect).is_visible_in_tree():
            face_bad.append("%s：名字牌上没有身份证图标" % id2)
        for which in ["名字牌", "头像"]:
            var target: Control = ui.name_plate if which == "名字牌" else face
            await real_click(target.get_global_rect().get_center())
            await frames(3)
            if ui.card == null:
                face_bad.append("%s：真点%s没开身份卡" % [id2, which])
            else:
                ui.close_card()
                await frames(2)
        ui.close_talk()
        await frames(2)
    for x in face_bad:
        print("    ", x)
    check("%d 位有头像的人（休息间、麻将室、化妆间）：3 倍整数倍、人左右不切、头顶顶着上沿、头像顶出框上沿、不压话和选项；名字牌有身份证图标、真点名字牌 / 头像开身份卡（%d 处不对）" % [people.size(), face_bad.size()], face_bad.is_empty() and people.size() >= 6)

    print("3 没头像的")
    var nop_bad: Array = []
    var mk = null
    for lf in all_lives:
        if lf.room == "makeup":
            mk = lf
    if mk == null:
        nop_bad.append("找不到化妆间那份人")
    else:
        # 先跟奶奶说一句（有头像），再跟新娘：新娘不能留着奶奶的图
        reenter()
        b.reset_to(door)
        ui.open_talk("lounge_09")
        for i in 200:
            await process_frame
            if ui.talk_box.visible and ui.line_raw != "":
                break
        await frames(4)
        var had_face: bool = ui.portrait.visible and ui.portrait.texture != null
        ui.close_talk()
        await frames(2)
        await enter_life(mk)
        ui.open_talk("bride")
        for i in 200:
            await process_frame
            if ui.talk_box.visible and ui.line_raw != "":
                break
        await frames(6)
        var face2: Control = ui.portrait.get_parent() as Control
        var shown_img := false
        if ui.portrait.visible and ui.portrait.texture != null and face2.visible:
            shown_img = true
        var txt_x: float = typer.shown.get_global_rect().position.x - ui.talk_box.get_global_rect().position.x
        if not had_face:
            nop_bad.append("先开的奶奶那一次就没头像（测试前提不成立）")
        if shown_img:
            nop_bad.append("新娘对话框还放着头像（可能是奶奶的）")
        if not ui.talk_box.visible or ui.name_label.text != "新娘":
            nop_bad.append("新娘对话框没开 / 名字牌「%s」" % ui.name_label.text)
        print("    新娘对话框：头像 %s、话从框左 %.0f 起（名字牌在左边，话照旧从名字牌那一栏右边起）" % [str(shown_img), txt_x])
        ui.close_talk()
        await frames(2)
    # 阿鱼那个说话框
    m._say("到啦～ 罗曼山庄 席还没散", -1.0, "阿鱼")
    await frames(6)
    var dlg_imgs: Array = []
    for tr in m.dialog.find_children("*", "TextureRect", true, false):
        if (tr as TextureRect).visible and (tr as TextureRect).texture != null and (tr as TextureRect).is_visible_in_tree():
            dlg_imgs.append(str((tr as TextureRect).name))
    var d_typer = m.dialog.get_node_or_null("typer")
    var txt_x2: float = d_typer.shown.get_global_rect().position.x - m.dialog.get_global_rect().position.x if d_typer != null else -1.0
    print("    阿鱼的说话框：头像图 %s、话从框左 %.0f 起" % [str(dlg_imgs), txt_x2])
    if not dlg_imgs.is_empty():
        nop_bad.append("阿鱼说话框里有图 %s（不该有头像）" % str(dlg_imgs))
    m.dialog.visible = false
    for x in nop_bad:
        print("    ", x)
    check("没头像的：新娘对话框不放头像（也不留奶奶的图）；阿鱼的说话框没有头像（%d 处不对）" % nop_bad.size(), nop_bad.is_empty())

    print("4 冒泡白底、对话框开着别的不冒")
    var bub_bad: Array = []
    reenter()
    life.show_bubble("lounge_09", "今天天气真好")
    await frames(3)
    var bn: Node2D = life.bubbles.get("lounge_09")
    if bn == null:
        bub_bad.append("冒泡没出来")
    else:
        var pnl: Panel = null
        for pn in bn.find_children("*", "Panel", true, false):
            pnl = pn
        var sb: StyleBox = pnl.get_theme_stylebox("panel")
        var col := Color(0, 0, 0, 0)
        if sb is StyleBoxFlat:
            col = (sb as StyleBoxFlat).bg_color
        elif sb is StyleBoxTexture and (sb as StyleBoxTexture).texture != null:
            var im: Image = (sb as StyleBoxTexture).texture.get_image()
            col = im.get_pixel(im.get_width() / 2, im.get_height() / 2)
        if col.r < 0.95 or col.g < 0.95 or col.b < 0.95 or col.a < 0.99:
            bub_bad.append("冒泡框中间的颜色 %s（该是白、不透明）" % str(col))
        var lbc := Color.WHITE
        for lb in bn.find_children("*", "Label", true, false):
            lbc = (lb as Label).get_theme_color("font_color")
        if lbc.r > 0.25 or lbc.g > 0.25 or lbc.b > 0.25:
            bub_bad.append("冒泡字颜色 %s（该是黑字）" % str(lbc))
        print("    冒泡框底色 %s、字色 %s" % [str(col), str(lbc)])
    # 对话框开着：三间都不冒
    for lf in b.lives:
        for id in lf.bubbles.keys():
            lf._hide_bubble(id)
    reenter()
    ui.open_talk("lounge_09")
    for i in 200:
        await process_frame
        if ui.talk_box.visible and ui.line_raw != "":
            break
    var leak := 0
    for step in int(40.0 / DT):
        tick(1)
        for lf in b.lives:
            for id in lf.bubbles:
                if is_instance_valid(lf.bubbles[id]):
                    leak += 1
    ui.close_talk()
    for x in bub_bad:
        print("    ", x)
    check("冒泡白底黑字；对话框开着 40 秒三间一个泡都不冒（冒了 %d 次）（%d 处不对）" % [leak, bub_bad.size()], bub_bad.is_empty() and leak == 0)

    DirAccess.remove_absolute("user://test_dbc_court.json")
    DirAccess.remove_absolute("user://test_dbc_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
