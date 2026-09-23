extends SceneTree
## 验收：席间小游戏的公用框架（蓝图 3.2）+ 样板游戏 2048。无界面跑，只看逻辑。
## 别的五个游戏各有自己的 tools/test_game_<id>.gd
## 用法：Godot --headless --path . --script res://tools/test_games.gd

const Cfg = preload("res://scripts/games/game_config.gd")
const Save = preload("res://scripts/games/game_save.gd")
const G2048 = preload("res://scripts/games/g2048.gd")
const Host = preload("res://scripts/games/game_host.gd")

var started := false

func _process(_dt: float) -> bool:
    if started:
        return false
    started = true
    run()
    return false

func run() -> void:
    var ok := true

    # 1. 配置：6 个游戏、12 张桌两两一组，每桌都找得到游戏
    var ids: Array = []
    for gg in Cfg.data()["games"]: ids.append(gg["id"])
    var tables_ok := true
    for i in range(1, 13):
        if Cfg.game_for_table("T%d" % i).is_empty(): tables_ok = false
    print("1 游戏 ", ids, " 12 张桌都有游戏 ", tables_ok)
    ok = ok and ids.size() == 6 and tables_ok

    # 2. 难度：第 1 关、第 5 关、第 30 关的参数；难度倍数 1.5 时 hard=1 的变大、hard=-1 的变小，都不出 min/max
    var llk := Cfg.game("lianliankan")
    var p1 := Cfg.params(llk, 1)
    var p5 := Cfg.params(llk, 5)
    var p30 := Cfg.params(llk, 30)
    var p1h := Cfg.params(llk, 1, 1.5)
    print("2 连连看 第1关 ", p1, " 第5关 ", p5, " 第30关 ", p30, " 第1关难度×1.5 ", p1h)
    # 9/20 体验评审第 9 条：8×8 时每格 42 像素（约 29 点）比手指小，列数封顶从 8 降到 7
    ok = ok and p1["kinds"] == 4.0 and p5["kinds"] == 8.0 and p30["kinds"] == 12.0 and p30["rows"] == 7.0
    ok = ok and p1h["kinds"] == 6.0 and p1h["time"] < p1["time"]
    print("  金币 第1关 ", Cfg.reward(llk, 1), " 第5关 ", Cfg.reward(llk, 5), " 第30关 ", Cfg.reward(llk, 30))
    # 第 30 关早就到顶：等于 json 里的 reward.max（9/19 01 调难度时从 60 提到 80，这里跟着配置走，不写死）
    ok = ok and Cfg.reward(llk, 1) == 10 and Cfg.reward(llk, 30) == int(llk["reward"]["max"])

    # 3. 存档：通关加金币、记关、解锁菜；添礼金扣金币；金币不够添不了；存云上成功才算干净
    var s := Save.new()
    s.local_path = "user://test_games_save.json"
    var sent: Array = []
    var answer := [true]
    s.saver = func(payload, done): sent.append(payload); done.call(answer[0])
    s.clear_level("lianliankan", 1, 10, 0)
    s.clear_level("g2048", 1, 10)
    s.clear_level("g2048", 2, 15)
    var gift_ok: bool = s.give_gift(20)
    var gift_too_much: bool = s.give_gift(999)
    print("3 存档：金 ", s.coins, " 进度 ", s.games, " 菜 ", s.dishes, " 添礼金累计 ", s.gift_coins, " 添 20 ", gift_ok, " 添 999 ", gift_too_much,
        " 存了 ", sent.size(), " 次 最后一次 ", sent[-1] if not sent.is_empty() else {})
    ok = ok and s.coins == 15 and s.games["g2048"] == 2 and s.dishes == [0] and s.gift_coins == 20 and gift_ok and not gift_too_much
    ok = ok and sent[-1].get("gift_add", 0) == 20 and not s.dirty
    answer[0] = false
    s.clear_level("g2048", 3, 20)
    var dirty_after_fail := s.dirty
    var pushed_before := sent.size()
    s.apply_cloud({"coins": 0, "games": {}})   # 有没存上的改动：不拿云上的旧数盖，先推上去
    print("  存失败后 dirty ", dirty_after_fail, " 进厅时推上去 ", sent.size() > pushed_before, " 金币还是 ", s.coins)
    ok = ok and dirty_after_fail and sent.size() > pushed_before and s.coins == 35
    answer[0] = true
    var s2 := Save.new()
    s2.local_path = "user://test_games_save2.json"
    s2.apply_cloud({"coins": 77, "games": {"match3": 4}, "dishes": [0, 1], "gift_coins": 8})
    print("  换手机：拿云上的 金 ", s2.coins, " 进度 ", s2.games, " 下一关 ", s2.next_level("match3"))
    ok = ok and s2.coins == 77 and s2.next_level("match3") == 5

    # 4. 2048 逻辑：挤一行、合一次、整盘滑、能不能动
    var r1 := G2048.slide_line([1, 1, 2, 0])
    var r2 := G2048.slide_line([2, 2, 2, 2])
    var r3 := G2048.slide_line([0, 3, 0, 3])
    print("4 2048 [1,1,2,0]→", r1["line"], " [2,2,2,2]→", r2["line"], " [0,3,0,3]→", r3["line"])
    ok = ok and r1["line"] == [2, 2, 0, 0] and r2["line"] == [3, 3, 0, 0] and r3["line"] == [4, 0, 0, 0]
    var b := [[1, 0, 0, 1], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]]
    var mr := G2048.move(b, Vector2i(1, 0))
    var ml := G2048.move(b, Vector2i(0, 1))
    print("  往右 ", mr["board"][0], " 合在 ", mr["merged"], " 往下 第一列 ", [ml["board"][3][0], ml["board"][3][3]])
    ok = ok and mr["board"][0] == [0, 0, 0, 2] and mr["merged"] == [Vector2i(3, 0)] and ml["board"][3][0] == 1
    var stuck := [[1, 2, 1, 2], [2, 1, 2, 1], [1, 2, 1, 2], [2, 1, 2, 1]]
    print("  满盘没得合 能动 ", G2048.can_move(stuck))
    ok = ok and not G2048.can_move(stuck)

    # 5. 外壳 + 2048 走一整关：目标第 3 级，一直随便滑，要么过要么输，外壳要记金币
    var root := Control.new()
    root.size = Vector2(540, 960)
    get_root().add_child(root)
    var s3 := Save.new()
    s3.local_path = "user://test_games_save3.json"
    s3.saver = func(_p, done): done.call(true)
    var host = Host.new()
    root.add_child(host)
    host.open("g2048", "T5", s3, SystemFont.new(), true)
    host.k = 1.0
    host.g = Cfg.game("g2048").duplicate(true)
    host.g["levels"]["target_pow"] = {"base": 3, "step": 0, "int": true}
    host._start()
    var result := [null]
    host.game.finished.connect(func(w, _why): result[0] = w)
    var dirs := [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]
    for i in 400:
        if result[0] != null:
            break
        host.game.play(dirs[i % 4])
    print("5 外壳里玩 2048（目标第 3 级）：结果 ", result[0], " 金币 ", s3.coins, " 进度 ", s3.games)
    ok = ok and result[0] == true and s3.coins == Cfg.reward(host.g, 1) and s3.cleared("g2048") == 1

    # 6. 真把棋盘画出来（9/20 换成 GPT 的菜牌图以后，2048 开局 16 格全空、一点就是空棋盘，
    #    原因是外面去摸牌子里第一个孩子当 Label 用。以前的测试只走逻辑、没走到「画格子」，所以没抓到）
    var g = host.game
    var drawn: int = g.cells.size()
    var on_board := 0
    for row in g.board:
        for k in row:
            if int(k) > 0:
                on_board += 1
    var captions: Array = []
    var art_with_text := 0
    var plain := 0
    for c in g.cells:
        var has_pic := false
        var txt := ""
        for kid in (c as Panel).get_children():
            if kid is TextureRect:
                has_pic = true
            elif kid is Label and str((kid as Label).text) != "":
                txt = str((kid as Label).text)
        if has_pic:
            if txt != "":
                art_with_text += 1
        else:
            plain += 1
            captions.append(txt)
    print("6 棋盘画出来了：", drawn, " 张牌，盘上 ", on_board, " 格有菜，色块牌上的名字 ", captions)
    ok = ok and drawn > 0 and drawn == on_board
    # 有图的牌一个字都不叠（阿鱼 9/23：「不要放文字，看起来很乱」）；退回色块的牌照旧写那一级叫什么，不然分不出先后
    var all_named := captions.size() == plain
    for cap in captions:
        if not g.steps().has(cap):
            all_named = false
    ok = ok and all_named and art_with_text == 0
    print("  有图的牌上叠了字的 ", art_with_text, " 张（该是 0）；色块牌都带名字、名字都在那张菜谱里 ", all_named)

    # 7. 两套图别混（03 9/20 报的：一级「花生」配了鱼的图）。
    #    小菜合大菜每关一种作物、各用各的那套图（crop_NN），不拿共用那 12 张凑；另外五个游戏照旧用共用那 12 张。
    #    一套十张缺一张就整关退回色块 + 名字，不许半图半色块（9/21 加的判断）
    var Tiles = load("res://scripts/games/tiles.gd")
    var shared_tex = Tiles.dish_art(0, "shared")
    var lv_set: String = g.art_set
    var lv_ready: bool = lv_set != ""
    print("7 这一关（第 ", g.level, " 关 ", str(g.crop().get("title", "")), "）用的套 ", "「" + lv_set + "」" if lv_ready else "没有（图还没交）",
        "，共用菜牌 ", "有" if shared_tex != null else "没有")
    ok = ok and shared_tex != null
    var pics := 0
    for c in g.cells:
        for kid in (c as Panel).get_children():
            if kid is TextureRect:
                pics += 1
    if not lv_ready:
        # 这一关的图没交齐：盘上一张图都不该有（宁可全色块，也别一半图一半色块）
        print("  图没交齐，整盘退回色块 + 名字：盘上图片数 ", pics)
        ok = ok and pics == 0 and drawn > 0
    else:
        print("  图交齐了，每格都该有图：", pics, "/", drawn)
        ok = ok and pics == drawn and drawn > 0
    var shared_tile: Panel = Tiles.dish_tile(0, 48.0, SystemFont.new(), 24)
    var shared_pics := 0
    for kid in shared_tile.get_children():
        if kid is TextureRect:
            shared_pics += 1
    print("  另外五个游戏照旧用共用那 12 张：一张牌里有 ", shared_pics, " 张图")
    ok = ok and shared_pics == 1
    shared_tile.queue_free()

    # 8. 顶栏状态那行放得下（第 38 版「目标 抽杆 现在最大 …」右边被截掉一截）：
    #    按手机上的面板宽（540 宽的屏，面板 520）排一次，所有作物里最长的一句用游戏那个像素字体量
    var pix: Font = load("res://assets/fonts/fusion-pixel-12px-proportional-zh_hans.otf.woff2")
    host.panel.size = Vector2(520, 880)
    host._layout()
    var lad = JSON.parse_string(FileAccess.get_file_as_string("res://assets/minigames/ladder.json"))
    var widest := 0.0
    var widest_s := ""
    for ck in lad["crops"]:
        for sa in lad["crops"][ck]["steps"]:
            for sb2 in lad["crops"][ck]["steps"]:
                var line := "目标 %s 现在最大 %s" % [sa, sb2]
                var w := pix.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
                if w > widest:
                    widest = w
                    widest_s = line
    var sl: Label = host.status_l
    var lv_w := pix.get_string_size("第 10 关", HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x
    var fits: bool = widest <= sl.size.x and sl.position.x + sl.size.x <= 520.0 - 12.0 + 0.5 and sl.position.x >= 14.0 + lv_w
    print("8 顶栏状态那行：最长「", widest_s, "」", widest, " 宽，给了 ", sl.size.x, "（从 x ", sl.position.x, " 起，不压「第 10 关」、不出面板）", fits)
    ok = ok and fits
    # 8b. 让开微信右上角的胶囊（A1，体验第一轮）：胶囊按屏幕算，右边 x ≥ CAPSULE_LEFT、y ≤ CAPSULE_BOTTOM 那一块。
    #     顶栏的字（游戏名、金币、第 N 关、状态、状态那行的小图）一样都不许落在里面；游戏区也在胶囊下面
    var p0: Vector2 = host.panel.global_position
    var cap := Rect2(Vector2(Host.CAPSULE_LEFT, 0), Vector2(540.0 - Host.CAPSULE_LEFT, Host.CAPSULE_BOTTOM))
    var clear := true
    var hit: Array = []
    for pair in [["游戏名", host.title_l], ["金币", host.coins_l], ["第 N 关", host.level_l], ["状态", host.status_l], ["状态小图", host.status_box]]:
        var c: Control = pair[1]
        var r := Rect2(p0 + c.position, c.size)
        if r.intersects(cap):
            clear = false
            hit.append(pair[0])
    var area_top: float = p0.y + host.area.position.y
    print("8b 顶栏让开胶囊（右上 x≥%.0f、y≤%.0f）：压着的 %s；金币右沿 %.0f，第二行 y %.0f，游戏区顶 %.0f、高 %.0f" % [
        Host.CAPSULE_LEFT, Host.CAPSULE_BOTTOM, hit, p0.x + host.coins_l.position.x + host.coins_l.size.x,
        p0.y + host.status_l.position.y, area_top, host.area.size.y])
    ok = ok and clear and area_top >= Host.CAPSULE_BOTTOM

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
