extends SceneTree
## 验收：罗曼山庄后厅（蓝图 3.3，灰盒，01 9/19 派任务 7）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 布局：六个交互点和蓝图一字不差、四个房门走得通、门之间和房间之间是墙、房间之间只能从走廊绕；麻将室四个长辈坐着、厨房一个厨师、
## 休息间没人只有一件外套、礼服架只有架子。进出：宴会厅东侧门 (1500,600,50) 进后厅站 (100,780)（蓝图 (50,780)，01 定挪开 1 米），
## 西口回宴会厅站 (1440,600)，两头都不来回弹，座位、金币、NPC 宾客都还在。四个房间：走进半径出按钮，话还是「【待补】」的不出按钮（01 E 10/3），塞了真话的点一下一句
## （话没定前不空着），再点关掉，走出去按钮和话都收。东口（厨房后门）去草坪（9/19 任务 8 起）。整条路 迎宾院 → 宴会厅 → 后厅 → 宴会厅 → 迎宾院
## 用法：Godot --headless --path . --script res://tools/test_backhall.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0
const ROOMS := ["dress", "lounge", "mahjong", "pot"]

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true
    m.hall_variant_once = ""   # 这套测的是第 44 版 12 桌厅（第 52 版起默认 55 桌，第 44 版留着）；只这一次，不写本机开关
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

## 手动推几帧：当前画布走路、main 管切画布
func tick(n: int) -> void:
    for i in n:
        m.cv._process(DT)
        m._process(DT)

## 走到某点（点地面的走法），最多走 secs 秒；到了或者路走完就停
func walk_to(target: Vector2, secs := 20.0) -> void:
    m.cv.go_to(target)
    for i in int(secs / DT):
        tick(1)
        if m.cv.path.is_empty():
            break

## 布局里这个名字标在哪。体验第二轮 新 1（01 9/24）起东西的名字牌不再挂在图上（只留出口牌），所以查布局数据，不查画出来的字
func label_at(canvas, text: String) -> Vector2:
    for it in canvas.cfg.get("flat", []):
        if str(it.get("type", "")) == "label" and str(it.get("text", "")) == text:
            return Vector2(float(it["x"]), float(it["y"]))
    for it in canvas.cfg.get("items", []):
        if it.has("label") and str(it["label"]["text"]) == text:
            var foot := float(it.get("y", it["rect"][3] if it.has("rect") else 0.0))
            return Vector2(canvas._item_center_x(it), foot + float(it["label"].get("dy", -40)))
    return Vector2(-1, -1)

func run() -> void:
    # 进厅小卡那一套（有人敬过就先放干杯插图、放完才能走）这里不看，关掉，免得一进厅走路被插图挡住
    m.cloud.fake_no_news = true
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    var b = m.backhall
    var h = m.hall
    m.games_save.local_path = "user://test_backhall_games.json"
    m.court_save.local_path = "user://test_backhall_court.json"

    # 1. 布局对蓝图 3.3
    print("1 布局对蓝图 3.3")
    var want := {"dress": [168, 400, 60], "lounge": [504, 420, 60], "mahjong": [840, 470, 70], "pot": [1272, 380, 70],
        "to_hall": [40, 780, 50], "to_lawn": [1500, 780, 50]}
    var same: bool = b.points.size() == 6
    for id in want:
        same = same and b.points.has(id) and b.points[id]["pos"] == Vector2(want[id][0], want[id][1]) and is_equal_approx(float(b.points[id]["r"]), float(want[id][2]))
    check("六个交互点坐标、半径和蓝图一字不差", same)
    var doors := true
    for dx in [168, 504, 840, 1176]:
        doors = doors and b._free(Vector2(dx, 690))
    check("四个房门 (168/504/840/1176, 690) 走得通", doors)
    var walls := true
    for p in [Vector2(60, 690), Vector2(300, 690), Vector2(650, 690), Vector2(1000, 690), Vector2(1400, 690),
            Vector2(336, 450), Vector2(672, 450), Vector2(1008, 450)]:
        walls = walls and not b._free(p)
    check("门之间的墙、房间之间的墙走不过去", walls)
    var cross: Array = b.find_path(Vector2(168, 450), Vector2(504, 470))
    var deepest := 0.0
    for p in cross:
        deepest = maxf(deepest, (p as Vector2).y)
    check("化妆室到休息间要从走廊绕（最低走到 y %.0f）" % deepest, not cross.is_empty() and deepest > 696.0)
    check("到了站的点 %s 离西口 %.0f 像素（至少 48）" % [b.SPAWN, b.SPAWN.distance_to(b.points["to_hall"]["pos"])],
        b.SPAWN == Vector2(100, 780) and b.SPAWN.distance_to(b.points["to_hall"]["pos"]) >= 48.0 and b._free(b.SPAWN))
    for id in b.points:
        var pt: Vector2 = b.points[id]["pos"]
        var path: Array = b.find_path(b.SPAWN, pt)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else b.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(pt), b.points[id]["r"]], end.distance_to(pt) < float(b.points[id]["r"]))
    var elders := 0
    var cooks := 0
    var in_lounge := 0
    for id in b.npc_nodes:
        var s: Sprite2D = b.npc_nodes[id]
        if str(id).begins_with("elder") and s.position.x > 672 and s.position.x < 1008 and s.region_enabled:
            elders += 1
        if id == "cook" and s.position.x > 1008 and not s.region_enabled:
            cooks += 1
        if s.position.x > 336 and s.position.x < 672:
            in_lounge += 1
    check("麻将室四个长辈坐着（%d）、厨房一个厨师站着（%d）、休息间没人（%d）" % [elders, cooks, in_lounge], elders == 4 and cooks == 1 and in_lounge == 0)
    var coat := label_at(b, "外套")
    check("休息间只有一件外套（标签在 %s）" % coat, coat.x > 336 and coat.x < 672)
    var rack := label_at(b, "礼服架")
    check("化妆室有礼服架（架子占位，礼服等正式图）", rack.x > 0 and rack.x < 336 and b.world.has_node("rack_base") and b.world.has_node("rack_rail"))
    for room in ["化妆室", "休息间", "麻将室", "厨房"]:
        check("灰盒标签「%s」" % room, label_at(b, room).x >= 0)

    # 2. 宴会厅东侧门进后厅：站在 (100,780)，朝向不变，宴会厅停着，站在西口边不弹回去
    print("2 宴会厅东侧门进后厅")
    m.nickname = "小李"
    await m._enter_banquet()
    tick(2)
    check("宴会厅有东侧门 %s 半径 %.0f" % [h.side_door, h.side_door_r], h.side_door == Vector2(1500, 600) and is_equal_approx(h.side_door_r, 50.0))
    check("东侧门的门洞能站", h._free(Vector2(1480, 610)))
    # scene.json 里宴会厅能走的格子：原来 5081 格（9/18 第 26 版起），这次只在东墙门洞加了 19 格（x 1460～1500、y 600～650），
    # 别处一格没动（长凳前那条道是开场时另加的，不在 scene.json 里，这里不算）
    var n_walk := 0
    var outside := 0
    var grid_rows: Array = h.cfg["walk_grid"]["rows"]
    for j in grid_rows.size():
        var line: String = grid_rows[j]
        for i in line.length():
            if line.unicode_at(i) == 49:
                n_walk += 1
                if i * 10 >= 1460 and not (i * 10 < 1500 and j * 10 >= 600 and j * 10 < 650):
                    outside += 1
    check("scene.json 能走 %d 格 = 原来 5081 + 门洞 19；x 1460 往东的都在门洞里（门洞外 %d 格）" % [n_walk, outside], n_walk == 5100 and outside == 0)
    var sat := {}
    m.cloud.call_fn("changeSeat", {"tableId": "T2", "chairNo": 5}, func(r): sat["r"] = r)
    check("换座成功", bool(sat.get("r", {}).get("ok", false)))
    h.apply_change("T2", 5, m.cloud.openid())
    var coins0: int = m.games_save.coins
    m.games_save.clear_level("g2048", 1, 50)
    h.stand_up()
    walk_to(h.side_door + Vector2(-90, 0))
    walk_to(h.side_door)
    check("进了后厅 state=%s" % m.state, m.state == "backhall" and m.cv == b and b.visible and not h.visible)
    check("站在 (100,780) %s" % b.pos, b.pos == Vector2(100, 780))
    check("朝向没变（往东走是朝右）%s" % b.face, b.face == "right")
    check("宴会厅停着", h.process_mode == Node.PROCESS_MODE_DISABLED)
    check("后厅能走、底下没有宴会厅的按钮", b.walking_enabled and not m.sit_btn.visible and not m.person_btn.visible and not m.book_btn.visible)
    tick(60)
    check("站在西口边 60 帧不弹回宴会厅", m.state == "backhall")

    # 3. 西口回宴会厅：站在东侧门边 (1440,600)，不弹；座位、金币、NPC 宾客都还在
    print("3 西口回宴会厅")
    walk_to(b.spot_pos("to_hall"))
    check("回到宴会厅 state=%s" % m.state, m.state == "banquet" and m.cv == h and h.visible and not b.visible)
    check("站在 (1440,600) %s" % h.pos, h.pos == Vector2(1440, 600))
    tick(60)
    check("站在东侧门边 60 帧不弹回后厅", m.state == "banquet")
    check("座位还在 %s" % h.my_seat, str(h.my_seat.get("table_id", "")) == "T2" and int(h.my_seat.get("chair_no", 0)) == 5)
    check("金币还在 %d（原来 %d，通关加 50）" % [m.games_save.coins, coins0], m.games_save.coins == coins0 + 50)
    check("NPC 宾客还在", h.life != null and not h.npc_taken.is_empty())

    # 4. 四个房间：走进半径出按钮；点一下一句（话没定之前是【待补】），再点关掉，再点又出；走出去按钮和话都收
    print("4 四个房间")
    walk_to(h.side_door + Vector2(-90, 0))
    walk_to(h.side_door)
    check("又进了后厅", m.state == "backhall")
    var ui = m.backhall_ui
    m.dialog.visible = false   # 进厅那句「到啦～」按真时间几秒就收；这里只推帧不走真时间，手动收掉
    var want_btn := {"dress": "礼服架", "lounge": "外套", "mahjong": "麻将桌", "pot": "穿上围裙 · 学做菜"}
    # 话还是【待补】的那几间：走进去不出按钮（01 E 10/3：开发字样不给玩家看）
    var hidden_ok := true
    for id in ["dress", "lounge", "mahjong"]:
        var sp0: Vector2 = b.spot_pos(id)
        walk_to(Vector2(sp0.x, 790))
        walk_to(sp0)
        hidden_ok = hidden_ok and b.in_spot(id) and not ui.act_btn.visible
    check("话还是【待补】的三间，走进去不出按钮", hidden_ok)
    walk_to(Vector2(b.spot_pos("lounge").x, 790))
    # 下面照阿鱼写好了的样子测：往读进来的话里塞三句（不动文件）
    var real := {"dress": "测试：礼服架这句", "lounge": "测试：外套这句", "mahjong": "测试：打两圈这句"}
    var bl: Dictionary = CourtCopy._lines(CourtCopy.BACKHALL)
    var saved := {}
    for id in real:
        saved[id] = bl[id].duplicate()
        bl[id]["text"] = real[id]
    var want_who := {"dress": "阿鱼", "lounge": "阿鱼", "mahjong": "长辈", "pot": "厨师"}
    for id in ROOMS:
        var sp: Vector2 = b.spot_pos(id)
        walk_to(Vector2(sp.x, 790))
        walk_to(sp)
        check("%s：走进去出按钮「%s」" % [id, ui.act_btn.text], b.in_spot(id) and ui.act_btn.visible and ui.act_btn.text == want_btn[id])
        check("%s：还没点，不说话" % id, not m.dialog.visible)
        if id == "pot":
            ui._on_act()
            check("厨房按钮打开做菜面板并停住场景行走", is_instance_valid(m.game_host) and not b.walking_enabled)
            m.game_host._close()
            check("关闭做菜后恢复后厅行走", m.game_host == null and b.walking_enabled)
            await process_frame
            b.tap(b.get_viewport().get_canvas_transform() * Vector2(1272,258))
            tick(180)
            check("直接点锅会走近并打开做菜", is_instance_valid(m.game_host))
            if is_instance_valid(m.game_host): m.game_host._close()
            await process_frame
            continue
        ui._on_act()
        check("%s：点一下 %s「%s」" % [id, m.dialog_who.text, m.dialog_text.text],
            m.dialog.visible and m.dialog_text.text == real[id] and m.dialog_who.text == want_who[id])
        if id == "dress":
            # 真等 3.2 秒（平常一句话 2.4 秒加每字 0.09 秒就自己收了），这句不收
            await create_timer(3.2).timeout
            check("%s：真等 3 秒也不自己收" % id, m.dialog.visible and m.dialog_text.text == real[id])
        ui._on_act()
        check("%s：再点关掉" % id, not m.dialog.visible)
        ui._on_act()
        check("%s：再点又出" % id, m.dialog.visible and m.dialog_text.text == real[id])
        walk_to(Vector2(sp.x, 790))
        check("%s：走出去按钮和话都收" % id, not ui.act_btn.visible and not m.dialog.visible)

    # 5. 文件里话没定之前都是【待补】（上面塞的测试句不进文件）
    print("5 【待补】")
    var all_hold := true
    for id in ROOMS:
        var raw = JSON.parse_string(FileAccess.get_file_as_string(CourtCopy.BACKHALL))["lines"][id]["text"]
        all_hold = all_hold and str(raw) == "【待补】"
    check("文件里四句都还是【待补】（阿鱼定了填进去就出按钮）", all_hold)

    # 6. 说话框被别的话顶掉了：再点按钮是再说一遍，不是把别人的话关掉
    print("6 别的话顶掉")
    walk_to(Vector2(168, 790))
    walk_to(b.spot_pos("dress"))
    ui._on_act()
    m._say("别的话", 0.0, "阿鱼")
    ui._on_act()
    check("再点是再说一遍「%s」" % m.dialog_text.text, m.dialog.visible and m.dialog_text.text == real["dress"])
    ui._on_act()
    for id in saved:
        bl[id] = saved[id]

    # 7. 东口（厨房后门）去草坪（9/19 任务 8 起）：站在西北口边 (100,300)；从西北口回来站在厨房后门边 (1440,780)
    print("7 厨房后门")
    walk_to(Vector2(168, 790))
    walk_to(b.spot_pos("to_lawn"), 30.0)
    check("厨房后门进了草坪 state=%s，站在 %s" % [m.state, m.lawn.pos], m.state == "lawn" and m.lawn.pos == Vector2(100, 300))
    walk_to(m.lawn.spot_pos("to_backhall"))
    check("草坪西北口回到后厅、站在厨房后门边 %s" % b.pos, m.state == "backhall" and b.pos == Vector2(1440, 780))

    # 8. 离开后厅时按钮收起来：站在大锅前出着按钮，走回宴会厅
    print("8 离开后厅按钮收")
    walk_to(Vector2(1272, 790))
    walk_to(b.spot_pos("pot"))
    check("大锅前出按钮", ui.act_btn.visible)
    m._switch_canvas("banquet")
    check("回到宴会厅，按钮收了", m.state == "banquet" and not ui.act_btn.visible)

    # 9. 整条路：迎宾院 → 宴会厅 → 后厅 → 宴会厅 → 迎宾院
    print("9 整条路")
    walk_to(h.SPAWN + Vector2(0, -160))
    walk_to(h.door)
    var steps := [m.state]
    walk_to(m.court.spot_pos("to_hall") + Vector2(0, 150))
    walk_to(m.court.spot_pos("to_hall"))
    steps.append(m.state)
    walk_to(h.side_door + Vector2(-90, 0))
    walk_to(h.side_door)
    steps.append(m.state)
    walk_to(b.spot_pos("to_hall"))
    steps.append(m.state)
    walk_to(h.SPAWN + Vector2(0, -160))
    walk_to(h.door)
    steps.append(m.state)
    check("走过的画布 %s" % [steps], steps == ["court", "banquet", "backhall", "banquet", "court"])

    DirAccess.remove_absolute("user://test_backhall_games.json")
    DirAccess.remove_absolute("user://test_backhall_court.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
