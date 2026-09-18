extends SceneTree
## 验收：罗曼山庄迎宾院（蓝图 3.1，灰盒，01 9/19 派）。无界面跑整个 main.gd，云函数走 cloud.gd 的电脑假数据。
## 第一段：能走的格子连通、交互点都走得到、随机点地面不踩进占地；刚到一块画布时站在出口里不会来回弹；
##         迎宾院 ↔ 宴会厅来回走，席位、金币这些状态还在；东西小径出「还没修好」
## 用法：Godot --headless --path . --script res://tools/test_entrance.gd
## 最后一行 RESULT PASS 才算过

const Main = preload("res://scripts/main.gd")
const CourtCopy = preload("res://scripts/court_copy.gd")
const DT := 1.0 / 60.0

var m
var started := false
var ok := true

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

## 手动推几帧：当前画布走路、main 管切画布（不等真的帧，跑得快、结果稳定）
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

func run() -> void:
    for i in 600:
        if m.state == "title":
            break
        await process_frame
    await process_frame
    var c = m.court
    # 小游戏存档写到测试自己的文件，别写进这台电脑上游戏的真存档
    m.games_save.local_path = "user://test_entrance_games.json"

    # 1. 格子：进场点能站；十个有半径的交互点从进场点都走得到
    print("1 迎宾院的格子和交互点")
    var g: Dictionary = c.cfg["walk_grid"]
    check("进场点能站 %s" % str(c.SPAWN), c._free(c.SPAWN))
    check("交互点 10 个", c.points.size() == 10)
    for id in c.points:
        var p: Vector2 = c.points[id]["pos"]
        var path: Array = c.find_path(c.SPAWN, p)
        var end: Vector2 = path[path.size() - 1] if not path.is_empty() else c.SPAWN
        check("%s 走得到（离点 %.1f，半径 %.0f）" % [id, end.distance_to(p), c.points[id]["r"]], end.distance_to(p) < float(c.points[id]["r"]))

    # 2. 随机点 40 个能站的地方：都走得到，一步都不踩进挡住的格子
    print("2 随机点地面")
    var rng := RandomNumberGenerator.new()
    rng.seed = 31
    var tried := 0
    var reach := 0
    var stepped_in := 0
    c.walking_enabled = true
    while tried < 40:
        var t := Vector2(rng.randf_range(0, 1536), rng.randf_range(0, 1024))
        if not c._free(t):
            continue
        tried += 1
        c.reset_to(c.SPAWN)
        c.go_to(t)
        for f in 2400:
            c._process(DT)
            if not c._free(c.pos):
                stepped_in += 1
                break
            if c.path.is_empty():
                break
        if c.pos.distance_to(t) < 6.0:
            reach += 1
    check("试 40 个，走到 %d 个，踩进占地 %d 次" % [reach, stepped_in], reach == 40 and stepped_in == 0)

    # 3. 刚到时站在出口里（进场点就在大门的范围里）：不发；走出去再走回来才发
    print("3 刚到站在出口里不弹")
    var got: Array = []
    var cb := func(id, inside): got.append([id, inside])
    c.spot.connect(cb)
    c.reset_to(c.spot_pos("gate"))
    for i in 30:
        c._process(DT)
    check("站在大门里 30 帧不发", got.is_empty() and c.in_spot("gate"))
    c.go_to(c.spot_pos("gate") + Vector2(0, -150))
    for i in 300:
        c._process(DT)
    c.go_to(c.spot_pos("gate"))
    for i in 300:
        c._process(DT)
    check("走出去再回来：先发出、再发进 %s" % str(got.filter(func(e): return e[0] == "gate")),
        got.has(["gate", false]) and got.has(["gate", true]))
    c.spot.disconnect(cb)

    # 4. 正式流程：选完形象从迎宾院大门进来，先存资料，还不拿席位
    print("4 进山庄")
    m.nickname = "小李"
    await m._enter_court()
    check("在迎宾院 state=%s" % m.state, m.state == "court" and m.cv == c and c.visible and not m.hall.visible)
    check("宴会厅停着", m.hall.process_mode == Node.PROCESS_MODE_DISABLED)
    check("站在大门口 %s" % str(c.pos), c.pos == c.SPAWN)
    check("资料存了、还没拿席位", m.profile_saved and not m.hall_ready)
    check("大门口说「到啦～ 罗曼山庄 席还没散」", m.dialog.visible and m.dialog_text.text == m.LINE_ARRIVE)

    # 5. 走到楼门进宴会厅：站在厅门口，拿到席位；朝向不变
    print("5 楼门进宴会厅")
    walk_to(c.spot_pos("to_hall"))
    check("进了宴会厅 state=%s" % m.state, m.state == "banquet" and m.cv == m.hall and m.hall.visible and not c.visible)
    check("站在厅门口 %s" % str(m.hall.pos), m.hall.pos == m.hall.SPAWN)
    check("朝向没变（往楼门走是朝上）%s" % m.hall.face, m.hall.face == "up")
    check("拿到席位 %s" % str(m.hall.my_seat), m.hall_ready and str(m.hall.my_seat.get("table_id", "")) == "T1")

    # 6. 刚进厅就站在门口：不会马上弹回迎宾院
    print("6 厅门不来回弹")
    tick(60)
    check("站在厅门口 60 帧还在宴会厅", m.state == "banquet")

    # 7. 换个座、手上有金币，出厅门回迎宾院，再进来：都还在
    print("7 来回走状态还在")
    # 换座走正常的路：服务端换成功（T2 的 5 号空着；4 号假数据里小李坐着）再本地坐过去
    var sat := {}
    m.cloud.call_fn("changeSeat", {"tableId": "T2", "chairNo": 5}, func(r): sat["r"] = r)
    check("换座成功 %s" % str(sat.get("r", {})), bool(sat.get("r", {}).get("ok", false)))
    m.hall.apply_change("T2", 5, m.cloud.openid())
    # 金币也走正常的路：通关给 50 金，存进服务端（进厅时服务端的存档说了算，没存上的本机改动会先推上去）
    var coins0: int = m.games_save.coins
    m.games_save.clear_level("g2048", 1, 50)
    m.hall.stand_up()
    walk_to(m.hall.SPAWN + Vector2(0, -160))
    walk_to(m.hall.door)
    check("出厅门回到迎宾院 state=%s" % m.state, m.state == "court" and m.cv == c)
    check("站在 (768,260) %s" % str(c.pos), c.pos == Vector2(768, 260))
    tick(60)
    check("站在楼门边 60 帧不弹回宴会厅", m.state == "court")
    walk_to(c.spot_pos("to_hall") + Vector2(0, 150))
    walk_to(c.spot_pos("to_hall"))
    check("又进了宴会厅", m.state == "banquet")
    check("座位还在 %s" % str(m.hall.my_seat), str(m.hall.my_seat.get("table_id", "")) == "T2" and int(m.hall.my_seat.get("chair_no", 0)) == 5)
    check("金币还在 %d（原来 %d，通关加 50）" % [m.games_save.coins, coins0], m.games_save.coins == coins0 + 50)
    check("NPC 宾客还在", m.hall.life != null and not m.hall.npc_taken.is_empty())

    # 8. 西小径、东小径还没修好
    print("8 东西小径")
    walk_to(m.hall.SPAWN + Vector2(0, -160))
    walk_to(m.hall.door)
    walk_to(c.spot_pos("to_lake"))
    check("西小径：%s" % m.note.text, m.note_box.visible and m.note.text == CourtCopy.text("to_lake") and m.state == "court")
    walk_to(c.spot_pos("to_lawn"), 30.0)
    check("东小径：%s" % m.note.text, m.note.text == CourtCopy.text("to_lawn"))

    DirAccess.remove_absolute("user://test_entrance_games.json")
    print("RESULT ", "PASS" if ok else "FAIL")
    quit(0 if ok else 1)
