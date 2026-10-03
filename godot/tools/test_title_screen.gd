extends SceneTree
## 验收：开场（title_screen.gd，阿鱼 10/3 交的开屏页接进游戏）。无界面跑整个 main.gd，按手机屏 540×960 和长屏 540×1168 各过一遍：
## 1 引擎一起来开场就盖在最上面（黑幕、迎宾院面板都在它下面），预热时有进度条和字，没有 logo、按钮
## 2 背景等比铺满屏、居中（跟第 1 层 splash.js 一样的铺法）
## 3 预热完「轻触屏幕」→ 点一下 → 菜单：logo、两个按钮出来，角色点得到
## 4 位置：logo、按钮、音乐开关、署名都在屏内；按钮不压猫狗（点击区底边以下）；音乐开关不压 logo；六位的气泡都在屏内
## 5 点角色说话；「玩法说明」开、关；「进入游戏」→ 起名，开场淡出藏掉，音乐停
## 用法：Godot --headless --path . --script res://tools/test_title_screen.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")

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

func inside(r: Rect2, vs: Vector2) -> bool:
    return r.position.x >= -0.5 and r.position.y >= -0.5 and r.end.x <= vs.x + 0.5 and r.end.y <= vs.y + 0.5

func run() -> void:
    await process_frame                 # 第一帧之前设窗口大小不生效
    for shape in [[Vector2i(1080, 1920), Vector2(540, 960)], [Vector2i(1170, 2532), Vector2(540, 1168)]]:
        root.size = shape[0]
        await frames(3)
        var vs := root.get_visible_rect().size
        check("屏是 %s（%s）" % [shape[1], vs], vs.is_equal_approx(shape[1]) or (absf(vs.x - shape[1].x) < 1.0 and absf(vs.y - shape[1].y) < 1.0))
        m = Main.new()
        m.fast = true
        root.add_child(m)
        var t = m.title_screen
        # _ready 走到预热（hall.warm_up）那一下就停住等；这时候还没出第一帧，就是手机上引擎接手后第一眼看到的
        print("== ", vs)
        check("预热：有字、有进度条，没 logo、没按钮", t.phase == "warm" and t.tip.visible and not t.logo_box.visible and not t.menu.visible)
        await frames(3)
        check("开场在最上面（盖住黑幕）", t.get_index() > m.fade.get_index())
        check("开场铺满屏", t.size.is_equal_approx(vs))
        check("背景读出来了", t.bg_tex != null and t.bg_tex.get_size() == Vector2(540, 960))
        var k := maxf(vs.x / 540.0, vs.y / 960.0)
        var want := Rect2((vs - Vector2(540, 960) * k) / 2.0, Vector2(540, 960) * k)
        check("背景等比铺满、居中 %s" % t.stage, t.stage.is_equal_approx(want))
        # 预热走完（main 自己 await 着 warm_up），会到「轻触屏幕」
        for i in 600:
            if t.phase == "tap":
                break
            await process_frame
        check("预热完：轻触屏幕", t.phase == "tap" and t.tap_hint.visible and t.tap_catch.visible and m.state == "title")
        t.tap_catch.pressed.emit()
        await frames(2)
        check("点一下：菜单出来", t.phase == "menu" and t.menu.visible and t.logo_box.visible and t.music_btn.visible)
        check("点一下：音乐响了", t.bgm.playing)
        t.show_menu_now()            # 动画直接放完，量位置
        await frames(2)
        var logo_r: Rect2 = t.logo_box.get_global_rect()
        var menu_r: Rect2 = t.menu.get_global_rect()
        var music_r: Rect2 = t.music_btn.get_global_rect()
        check("logo 在屏内 %s" % logo_r, inside(logo_r, vs))
        check("logo 宽不超过屏宽 92%%（%.0f）" % logo_r.size.x, logo_r.size.x <= vs.x * 0.92 + 0.5)
        check("按钮在屏内 %s" % menu_r, inside(menu_r, vs))
        check("署名在屏内", inside(t.credit.get_global_rect(), vs))
        check("音乐开关在屏内", inside(music_r, vs))
        check("音乐开关不压 logo", not music_r.intersects(logo_r))
        check("音乐开关不压按钮", not music_r.intersects(t.start_btn.get_global_rect()) and not music_r.intersects(t.help_btn.get_global_rect()))
        var pets_bottom := 0.0
        for who in ["xiduo", "tiantian", "luoluo", "qiuqiu"]:
            pets_bottom = maxf(pets_bottom, t.hits[who].get_global_rect().end.y)
        check("按钮不压猫狗：按钮上沿 %.0f ≥ 猫狗下沿 %.0f" % [menu_r.position.y, pets_bottom], menu_r.position.y >= pets_bottom)
        check("按钮够大：进入游戏高 %.0f" % t.start_btn.size.y, t.start_btn.size.y >= 60.0)
        for who in t.WHO:
            var h: Rect2 = t.hits[who].get_global_rect()
            check("%s 点击区有一半以上在屏内" % who, h.intersection(Rect2(Vector2.ZERO, vs)).get_area() >= h.get_area() * 0.5)
            t.show_menu_now(who)
            await frames(2)
            var b: Rect2 = t.bubble.get_global_rect()
            check("%s 气泡在屏内 %s" % [who, b], inside(b, vs))
            check("%s 气泡在角色头上（气泡下沿在点击区上沿附近）" % who, absf(b.end.y + 12.0 - (t.stage.position.y + t.WHO[who]["at"][1] / 100.0 * t.stage.size.y)) < 1.0)
            check("%s 说的是自己的词" % who, t.bubble_name.text == t.WHO[who]["name"] and t.bubble_text.text in t.LINES[who])
        # 点角色：立刻说一句
        t.fast = false
        t._on_hit("qiuqiu")
        await frames(1)
        check("点求求：求求说话", t.bubble_who == "qiuqiu")
        t.fast = true
        # 玩法说明
        t.help_btn.pressed.emit()
        check("玩法说明打开", t.sheet.visible and inside(t.sheet_card.get_global_rect(), vs))
        t._close_help()
        check("玩法说明关上", not t.sheet.visible)
        # 进入游戏
        t.start_btn.pressed.emit()
        for i in 30:
            await process_frame
        check("进入游戏 → 起名", m.state == "nick" and m.screens["nick"].visible)
        check("开场藏了、音乐停了", not t.visible and not t.bgm.playing)
        check("没有删掉的那句台词", not ("凑齐七个人，才能解开这段奇缘哦" in t.LINES["bride"]))
        m.queue_free()
        await frames(2)
    print("RESULT PASS" if ok else "RESULT FAIL")
    quit(0 if ok else 1)
