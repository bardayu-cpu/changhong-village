extends SceneTree
## 验收：对话框开着时说话的人和玩家都露在框上面（04 第 1 条后半，05 10/4；镜头让开在 scripts/ui/dialog_skin.gd 的 _lift_tick）。
## 无界面跑整个 main.gd，按手机屏 540×960 和长屏 540×1168 各过一遍，进后厅：
## 1 麻将室大爷、休息间奶奶、化妆间新娘（没头像）各点开对话：等镜头让完，说话的人头顶脚下、玩家头顶脚下在屏幕上都在框上沿上面
## 2 关上：镜头放回原位（偏移回 0、画布下沿限位回原值）
## 3 一句超过 2 行分了页（阿鱼 10/5）：点框先出完这一页、再点框翻到下一页不跳句（罗-11）；点右边下三角翻到下一页、上三角翻回；第一页没有上三角、最后一页没有下三角
## 4 阿鱼说一句（没头像、没选项；加了“”以后可能两行）：框整个在屏幕里、下沿离底 40，框只比内容高一点（≤ 内容 + 44），名字牌和话上下居中
## 用法：Godot --headless --path . --script res://tools/test_dialog_lift.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const DialogSkin = preload("res://scripts/ui/dialog_skin.gd")

var m
var ok := true

func _initialize() -> void:
    run()

func check(name: String, cond: bool) -> void:
    print(("  好 " if cond else "  不行 ") + name)
    ok = ok and cond

func frames(n: int) -> void:
    for i in n:
        await process_frame

func life_by(b, room: String):
    for l in b.lives:
        if l.room == room:
            return l
    return b.lounge if room == "lounge" else null

func open_talk(b, ui, lf, id: String) -> void:
    if ui.is_open():
        ui.close_talk()
    await frames(3)
    b.reset_to(b.nearest_free(lf.approach_of(id)))
    b.cam.reset_smoothing()
    lf.request_talk(id)
    for i in 120:
        await process_frame
        if ui.talk_box.visible:
            break
    await frames(60)   # 镜头慢慢让，等让完

func run() -> void:
    await process_frame
    for shape in [[Vector2i(1080, 1920), Vector2(540, 960)], [Vector2i(1170, 2532), Vector2(540, 1168)]]:
        root.size = shape[0]
        await frames(3)
        var vs := root.get_visible_rect().size
        check("屏是 %s（%s）" % [shape[1], vs], absf(vs.x - shape[1].x) < 1.0 and absf(vs.y - shape[1].y) < 1.0)
        m = Main.new()
        m.fast = true
        root.add_child(m)
        for i in 900:
            if m.state == "title":
                break
            await process_frame
        m.nickname = "小李"
        m.cloud.fake_no_news = true
        m.ensure_canvas("backhall")
        m._show_canvas("backhall")
        m._goto("backhall")
        m.dialog.visible = false
        var b = m.backhall
        var ui = m.lounge_ui
        b.walking_enabled = true
        ui.attach(b.lounge)
        await frames(10)
        var limit0: int = b.cam.limit_bottom
        for pair in [["mahjong", "elder_n", "大爷"], ["lounge", "lounge_09", "奶奶"], ["makeup", "bride", "新娘"]]:
            # 10/5 03：化妆间 10/4 起是单独一间屋（areas["makeup"]，自己一块画布），新娘不在后厅那几份人里了：到化妆间那块画布里找人、量镜头
            var cv = b
            var lf = life_by(b, pair[0])
            var want_state := "backhall"
            # 10/6 庄Z2：麻将室也搬成单独一间（娱乐室，areas["mahjong"]），大爷跟着搬过去了
            if pair[0] in ["makeup", "mahjong"]:
                m.ensure_canvas(pair[0])
                cv = m.areas[pair[0]]
                lf = cv.lives[0] if not cv.lives.is_empty() else null
                want_state = pair[0]
            if m.state != want_state:
                if ui.is_open():
                    ui.hide_all()
                m.switching = false
                m._show_canvas(want_state)
                m._goto(want_state)
                await frames(10)
                cv.walking_enabled = true
            if lf == null or not lf.people.has(pair[1]):
                check("%s：找得到" % pair[2], false)
                continue
            var lim0: int = cv.cam.limit_bottom
            await open_talk(cv, ui, lf, pair[1])
            check("%s：对话框开了" % pair[2], ui.talk_box.visible)
            var top: float = ui.talk_box.get_global_rect().position.y
            var xf: Transform2D = cv.get_global_transform_with_canvas()
            var p: Dictionary = lf.people[pair[1]]
            var who_y := maxf((xf * (p["foot"] as Vector2)).y, (xf * (p.get("head", p["foot"]) as Vector2)).y)
            var me_y := (xf * (cv.pos as Vector2)).y
            check("%s：说话的人露在框上面（脚 %.0f < 框上沿 %.0f）" % [pair[2], who_y, top], who_y < top)
            check("%s：玩家露在框上面（脚 %.0f < 框上沿 %.0f）" % [pair[2], me_y, top], me_y < top)
            ui.close_talk()
            await frames(90)
            check("%s：关上以后镜头放回原位（偏移 %.1f、下沿 %d）" % [pair[2], cv.cam.offset.y, cv.cam.limit_bottom], is_zero_approx(cv.cam.offset.y) and cv.cam.limit_bottom == lim0)
        # 回后厅继续下面的分页测试
        if m.state != "backhall":
            m.switching = false
            m._show_canvas("backhall")
            m._goto("backhall")
            await frames(10)
            b.walking_enabled = true
        # 分页：打字开着，点一下先出完、再点翻页
        var mj = life_by(b, "lounge")   # 10/6 大爷搬去娱乐室了，分页拿后厅休息间奶奶测
        await open_talk(b, ui, mj, "lounge_09")
        var typer = ui.talk_box.get_node("typer")
        typer.instant = false
        ui.line_label.text = "今天这天气真好，早上还有点凉，到中午就暖和了。等下开席有红烧肉、清蒸鱼，还有一锅老鸭汤，听说炖了一上午，你待会儿多吃点，别光顾着拍照。"
        await frames(2)
        check("长句分了页（%d 页）" % typer.pages.size(), typer.pages.size() >= 2)
        check("一开始在打字", DialogSkin.typing(ui.talk_box))
        var line_before: String = ui.line_label.text
        ui.next_line()
        await frames(1)
        check("点一下：这一页出完、还是这句话", not DialogSkin.typing(ui.talk_box) and typer.page == 0 and ui.line_label.text == line_before)
        check("第一页：有下三角、没有上三角", typer.down_btn.visible and not typer.up_btn.visible)
        ui.next_line()
        await frames(1)
        check("再点框：翻到第 2 页、还是这句话（页 %d；罗-11 点框也翻页）" % typer.page, typer.page == 1 and ui.line_label.text == line_before)
        typer.up_btn.pressed.emit()
        await frames(1)
        typer.down_btn.pressed.emit()
        await frames(1)
        check("点下三角：翻到第 2 页、还是这句话、出上三角", typer.page == 1 and ui.line_label.text == line_before and typer.up_btn.visible)
        typer.up_btn.pressed.emit()
        await frames(1)
        check("点上三角：翻回第 1 页", typer.page == 0)
        for k in 10:
            if typer.down_btn.visible:
                typer.down_btn.pressed.emit()
                await frames(1)
        check("翻到最后一页：没有下三角（页 %d / %d）" % [typer.page + 1, typer.pages.size()], typer.page == typer.pages.size() - 1 and not typer.down_btn.visible)
        check("每页最多 2 行", typer.pages.all(func(pg): return (pg as String).count("\n") <= 1))
        check("三角能点的范围 ≥ 44×44（%s）" % typer.down_btn.size, typer.down_btn.size.x >= 44.0 and typer.down_btn.size.y >= 44.0)
        typer.instant = true
        ui.close_talk()
        await frames(60)
        # 阿鱼一行：框在屏里、排匀
        m._say("到啦～ 罗曼山庄 席还没散", 0.0)
        await frames(10)
        var r: Rect2 = m.dialog.get_global_rect()
        check("阿鱼的框在屏里（%s，屏高 %.0f）" % [r, vs.y], r.end.y <= vs.y - 39.0 and r.position.y > vs.y * 0.5)
        var lay: Control = m.dialog.get_node("layer")
        var pl: Control = lay.get_node("lounge_name")
        var pg: Control = lay.get_node("page")
        var content := maxf(pl.size.y, pg.size.y)
        check("阿鱼的框排匀、不空一大块（高 %.0f、内容 %.0f）" % [r.size.y, content], r.size.y <= content + 44.0)
        var mid := r.size.y * 0.5
        check("名字牌、话上下居中（牌 %.0f、话 %.0f、框中 %.0f）" % [pl.position.y + pl.size.y * 0.5, pg.position.y + pg.size.y * 0.5, mid], absf(pl.position.y + pl.size.y * 0.5 - mid) <= 2.0 and absf(pg.position.y + pg.size.y * 0.5 - mid) <= 2.0)
        m.dialog.visible = false
        await frames(30)
        m.queue_free()
        await frames(3)
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
