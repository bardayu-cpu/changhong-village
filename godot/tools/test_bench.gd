extends SceneTree
## 验收：宴会厅长凳（蓝图 3.2「座位上限 120，满了新来的人坐在墙边的长凳上，长凳无限，能做所有动作」，01 9/19 派任务 5）。
## 无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据（bench 和服务端 enterHall 一样是 openid 列表，坐长凳的 chair_no 是 null）。
## 凳子摆在北墙根、不在原来能走的格子里、不挡路；凳前补的那条道走得进去；凳子上的人坐成一排，人少一人 30 像素，多了挤着叠，
## 每一个都点得到（站到跟前名字按钮就是他），T3 后排有人时站在原来那一行点到的还是 T3 的人；看人卡片、敬一杯（他站到凳子跟前）、
## 想认识你都和桌边一样；凳子不出「坐这儿」、没有簿子和小游戏；我被分到长凳：不报错、金标在凳子上我那个位置、顶部一句；
## 从长凳换到空椅子，坐下、金标跟过去、凳子上我的位置空出来
## 用法：Godot --headless --path . --script res://tools/test_bench.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const Hall = preload("res://scripts/layered_hall.gd")

var m
var started := false
var ok := true

func _initialize() -> void:
    m = Main.new()
    m.fast = true   # 淡入淡出直接跳过
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

## 凳子上放 n 个人（fake_b0…），名字小凳 1、小凳 2…
func fill_bench(n: int) -> void:
    m.cloud.fake_bench = []
    for i in n:
        var oid := "fake_b%d" % i
        m.cloud.fake_bench.append(oid)
        m.cloud.fake_names[oid] = {"nick": "小凳%d" % (i + 1), "avatar": i % 8, "inviter": null}

## 进一次厅（假 enterHall 回来就画好了）
func enter() -> void:
    await m._enter_banquet()
    await frames(3)

## 站到某处，马上扫一遍旁边的人、椅子、桌子
func stand(p: Vector2) -> void:
    m.hall.reset_to(p)
    await frames(1)

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await frames(2)
    var h = m.hall

    # 1. 凳子：北墙根，靠背和凳面两块；原来能走的格子一格不少，凳子这块本来就走不进去；凳前补的那条道能走、从门口走得到
    print("1 凳子摆在哪")
    check("有靠背、有凳面", h.world.has_node("bench_back") and h.world.has_node("bench_seat"))
    var cfg_rows: Array = h.cfg["walk_grid"]["rows"]
    var lost := 0
    for j in cfg_rows.size():
        var line: String = cfg_rows[j]
        for i in line.length():
            if line.unicode_at(i) == 49 and h.walk[j * h.cols + i] != 1:
                lost += 1
    check("原来能走的格子一格没少（少了 %d）" % lost, lost == 0)
    var seat_cell: Vector2i = h._cell_of(Vector2((Hall.BENCH_X0 + Hall.BENCH_X1) * 0.5, Hall.BENCH_Y))
    check("凳子那一行原来就不能走、现在也不能走", cfg_rows[seat_cell.y].unicode_at(seat_cell.x) != 49 and not h._free(Vector2((Hall.BENCH_X0 + Hall.BENCH_X1) * 0.5, Hall.BENCH_Y)))
    var aisle := Vector2((Hall.BENCH_X0 + Hall.BENCH_X1) * 0.5, 268.0)
    check("凳前那条道能站", h._free(aisle))
    check("从门口走得到凳子跟前", not h.find_path(h.SPAWN, aisle).is_empty())
    var t3: Dictionary = h._table_cfg("T3")
    var t3_in := 0
    for r in Hall.BENCH_WALK:
        var rr: Rect2 = r
        if rr.intersects(Rect2(168, 291, 165, 148)):   # T3 那块积木（scene.json：x 168、y 291、图 165×148）
            t3_in += 1
    check("补的道不压 T3 的积木", t3_in == 0 and not t3.is_empty())

    # 2. 凳子上 8 个人：坐成一排，一人 30 像素、居中；都画出来了（和桌边的人一样记在 resident_nodes），椅子、坐人的椅子数都没变
    print("2 八个人一排")
    fill_bench(8)
    m.nickname = "阿花"
    await enter()
    m._note("")
    check("凳子上 8 个位置", h.bench_spots.size() == 8)
    var xs := []
    for b in h.bench_spots:
        xs.append((b["pos"] as Vector2).x)
    var in_row := true
    for k in xs.size():
        var p: Vector2 = h.bench_spots[k]["pos"]
        in_row = in_row and is_equal_approx(p.y, Hall.BENCH_Y) and p.x >= Hall.BENCH_X0 - 0.01 and p.x <= Hall.BENCH_X1 + 0.01
        if k > 0:
            in_row = in_row and is_equal_approx(xs[k] - xs[k - 1], Hall.BENCH_GAP)
    check("一排、间隔 30、都在凳子上 %s" % [xs], in_row)
    var drawn := 0
    for i in 8:
        if h.resident_nodes.has("fake_b%d" % i):
            drawn += 1
    check("8 个都画了", drawn == 8)
    check("椅子还是 120 把，凳子不算椅子", h.chairs.size() == 120)
    var bench_keys := 0
    for k in h.seat_taken.keys():
        if str(k).begins_with("bench"):
            bench_keys += 1
    check("坐人的椅子表里没有凳子", bench_keys == 0)

    # 3. 每一个都点得到：站到跟前，底下名字按钮就是他
    print("3 挨个站到跟前")
    var hit := 0
    for k in 8:
        await stand(Vector2(xs[k], 266.0))
        if h.person_near_key == "fake_b%d" % k and m.person_btn.visible and m.person_btn.text == "小凳%d" % (k + 1):
            hit += 1
    check("8 个人名字按钮都对（%d）" % hit, hit == 8)

    # 4. T3 后排有人（满厅的时候）：站在原来最北那一行，点到的是 T3 的人；往凳子那边走两步，就是凳子上的人
    print("4 和 T3 后排抢不抢")
    h.seat_taken["T3:1"] = "fake_wang"
    var c1: Vector2 = h.chair_world(t3, 1)
    await stand(Vector2(c1.x, 325.0))
    check("站在原来那一行：T3 后排的人（%s）" % h.person_near_key, h.person_near_key == "fake_wang")
    var near_k := 0
    for k in 8:
        if absf(xs[k] - c1.x) < absf(xs[near_k] - c1.x):
            near_k = k
    await stand(Vector2(xs[near_k], 264.0))
    check("走进凳前那条道：凳子上的人（%s）" % h.person_near_key, h.person_near_key == "fake_b%d" % near_k)
    h.seat_taken.erase("T3:1")

    # 5. 凳子不出「坐这儿」、没有簿子、没有小游戏
    print("5 凳子只有看人、敬酒")
    var chair_hits := []
    var cb := func(tid, no): chair_hits.append([tid, no])
    h.chair_near.connect(cb)
    for k in 8:
        await stand(Vector2(xs[k], 266.0))
    h.chair_near.disconnect(cb)
    var bench_chair := false
    for c in chair_hits:
        if str(c[0]) == Hall.BENCH_ID:
            bench_chair = true
    check("凳子上的位置从不出坐这儿", not bench_chair)
    check("凳子不是桌：没有簿子、没有小游戏", h.table_at(Vector2(xs[3], Hall.BENCH_Y)) == "" and m.GameCfg.game_for_table(Hall.BENCH_ID).is_empty())

    # 6. 看人卡片、敬一杯、想认识你：和桌边一样
    print("6 看人、敬酒、想认识你")
    await stand(Vector2(xs[4], 266.0))
    m._on_person_pressed()
    await frames(1)
    check("卡片：小凳5", m.card_open and m.person_card_name.text == "小凳5")
    m._on_meet_pressed()
    await frames(2)
    check("没同桌、没敬过：%s" % m.note.text, m.note.text == "先坐到一桌 或者敬一杯")
    m._open_person_card("fake_b4")
    await frames(1)
    m._on_toast_pressed()
    await frames(2)
    check("敬了：%s" % m.note.text, m.note.text == "敬了 小凳5 一杯")
    var st: Node = h.world.get_node_or_null("toast_stand")
    var want: Vector2 = h.bench_spots[4]["pos"] + Vector2(0, Hall.BENCH_STAND_DY)
    check("他站到凳子跟前（%s）" % [st.position if st != null else null], st != null and (st as Node2D).position.distance_to(want) < 0.5)
    check("坐着的那个先藏起来", not (h.resident_nodes["fake_b4"]["spr"] as Sprite2D).visible)
    m._open_person_card("fake_b4")
    await frames(1)
    m._on_meet_pressed()
    await frames(2)
    check("敬过以后想认识你：%s" % m.note.text, m.note.text == "想认识 小凳5 记下了")
    await m._shot_skip_entry_toast()

    # 7. 30 个人：挤着叠，还在凳子上、从西到东排，每一个站到跟前都点得到
    print("7 三十个人")
    fill_bench(30)
    await enter()
    var xs30 := []
    for b in h.bench_spots:
        xs30.append((b["pos"] as Vector2).x)
    var ordered := xs30.size() == 30
    for k in xs30.size():
        ordered = ordered and xs30[k] >= Hall.BENCH_X0 - 0.01 and xs30[k] <= Hall.BENCH_X1 + 0.01
        if k > 0:
            ordered = ordered and xs30[k] > xs30[k - 1]
    check("30 个都在凳子上、从西到东（间隔 %.1f）" % (xs30[1] - xs30[0]), ordered and xs30[1] - xs30[0] < Hall.BENCH_GAP)
    var hit30 := 0
    for k in 30:
        await stand(Vector2(xs30[k], 262.0))
        if h.person_near_key == "fake_b%d" % k:
            hit30 += 1
    check("30 个都点得到（%d）" % hit30, hit30 == 30)

    # 8. 我被分到长凳（服务端 table_id=bench、chair_no=null）：不报错，金标在凳子上我那个位置，我不画成坐着的，顶部一句
    print("8 我坐长凳")
    fill_bench(8)
    m.cloud.fake_bench.insert(3, "fake_me")
    m.cloud.fake_me = {"table_id": "bench", "chair_no": null}
    for tid in m.cloud.fake_seats:
        var arr: Array = m.cloud.fake_seats[tid]
        for i in range(arr.size() - 1, -1, -1):
            if arr[i]["openid"] == "fake_me":
                arr.remove_at(i)
    m.cloud.fake_no_news = true
    await enter()
    var mine: Vector2 = h.bench_spots[3]["pos"]
    check("我的位置是凳子上第 4 个", h.bench_spots.size() == 9 and h.bench_spots[3]["openid"] == "fake_me")
    check("金标在凳子上我那个位置", h._my_chair_pos() == mine and h.seat_marker != null and h.seat_marker.position == mine)
    check("我不画成坐着的", not h.resident_nodes.has("fake_me"))
    check("顶部：%s" % m.note.text, m.note.text == "桌子都坐满了 先坐墙边的长凳")
    await stand(Vector2(mine.x, 266.0))
    check("站在自己位置跟前，名字按钮不是我", h.person_near_key != "fake_me")
    check("凳子上不出小游戏", not m.play_btn.visible)

    # 9. 从长凳换到空椅子（T3 5 号）：坐下、金标跟过去，凳子上我的位置空出来，服务端那边也不在凳子上了
    print("9 从长凳换到椅子")
    var c5: Vector2 = h.chair_world(t3, 5)
    await stand(h._stand_spot(c5, h._seat_center(t3)))
    m.near_seat_info = {"table_id": "T3", "chair_no": 5}
    m.sit_target = {"table_id": "T3", "chair_no": 5}
    m.sit_confirming = true
    m._on_sit_pressed()
    await frames(2)
    check("坐到 T3 5 号：%s" % [h.my_seat], str(h.my_seat.get("table_id", "")) == "T3" and int(h.my_seat.get("chair_no", 0)) == 5 and h.seated)
    check("金标跟到椅子上", h.seat_marker != null and h.seat_marker.position == c5)
    var still := false
    for b in h.bench_spots:
        if b["openid"] == "fake_me":
            still = true
    check("凳子上我的位置空出来", not still and h.bench_spots.size() == 8)
    check("服务端那边也不在凳子上了", not m.cloud.fake_bench.has("fake_me"))
    m.cloud.fake_no_news = false

    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
